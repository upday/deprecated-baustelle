require 'ostruct'

module Platform
  module CloudFormation
    module EBEnvironment
      extend self

      def apply(template, env_name:, app_ref:, app_name:, vpc:, app_config:,
                stack_configurations:)
        template.eval do
          eb_env_name = "#{env_name}-#{app_name}".gsub('_', '-')
          template.resource env_name = "#{camelize(app_name)}Env#{camelize(env_name)}",
                            Type: "AWS::ElasticBeanstalk::Environment",
                            Properties: {
                              ApplicationName: app_ref,
                              CNAMEPrefix: eb_env_name,
                              EnvironmentName: eb_env_name,
                              OptionSettings: {
                                'aws:autoscaling:launchconfiguration' => {
                                  'EC2KeyName' => 'kitchen',
                                  'InstanceType' => app_config.fetch('instance_type'),
                                },
                                'aws:autoscaling:asg' => {
                                  'MinSize' => app_config.fetch('scale').fetch('min'),
                                  'MaxSize' => app_config.fetch('scale').fetch('max')
                                },
                                'aws:ec2:vpc' => {
                                  'VPCId' => vpc.id,
                                  'Subnets' => join(',', *vpc.zone_identifier),
                                  'ELBSubnets' => join(',', *vpc.zone_identifier),
                                  'AssociatePublicIpAddress' => 'true'
                                },
                                'aws:elasticbeanstalk:application:environment' => app_config.fetch('config')
                              }.map do |namespace, options|
                                options.map do |key, value|
                                  {
                                    Namespace: namespace,
                                    OptionName: key.to_s,
                                    Value: value.is_a?(Hash) ? value : value.to_s
                                  }
                                end
                              end.flatten
                            }.merge(EBEnvironment.stack(app_config.fetch('stack'),
                                                        stack_configurations: stack_configurations))

          ref(env_name)
        end
      end

      def stack(stack_name, stack_configurations:)
        stack = stack_configurations.fetch(stack_name)
        if stack.has_key?('solution')
          {SolutionStackName: stack['solution']}
        else
          raise "Malformed stack"
        end
      end

      def option_settings(config:, vpc:)

      end

    end
  end
end
