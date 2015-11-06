require 'ostruct'
require 'digest'

module Baustelle
  module CloudFormation
    module EBEnvironment
      extend self
      extend Baustelle::Camelize

      BACKEND_REGEX = %r{^backend\((?<type>[^:]+):(?<name>[^:]+):(?<property>[^:]+)\)$}

      def apply(template, stack_name:, env_name:, app_ref:, app_name:, vpc:, app_config:,
                stack_configurations:, backends:)
        env_hash = eb_env_name(stack_name, app_name, env_name)
        stack = solution_stack(template, app_config.fetch('stack'),
                               stack_configurations: stack_configurations)

        template.eval do
          eb_dns = {
            'Fn::Join' => [
              '-', [
                "#{stack_name}",
                template.ref('AWS::Region'),
                "#{env_name}-#{app_name}".gsub('_', '-')
              ]
            ]
          }

          template.resource env_name = "#{camelize(app_name)}Env#{camelize(env_name)}",
                            Type: "AWS::ElasticBeanstalk::Environment",
                            Properties: {
                              ApplicationName: app_ref,
                              CNAMEPrefix: eb_dns,
                              EnvironmentName: env_hash,
                              SolutionStackName: stack.fetch(:name),
                              OptionSettings: {
                                'aws:autoscaling:launchconfiguration' => {
                                  'EC2KeyName' => 'kitchen',
                                  'InstanceType' => app_config.fetch('instance_type')
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
                                'aws:elasticbeanstalk:application:environment' => EBEnvironment.extrapolate_backends(app_config.fetch('config', {}),
                                                                                                                     backends, template)
                              }.tap do |settings|
                                if ami = stack.fetch(:ami)
                                  settings['aws:autoscaling:launchconfiguration']['ImageId'] = ami
                                end
                              end.map do |namespace, options|
                                options.map do |key, value|
                                  {
                                    Namespace: namespace,
                                    OptionName: key.to_s,
                                    Value: value.is_a?(Hash) ? value : value.to_s
                                  }
                                end
                              end.flatten
                            }
          ref(env_name)
        end
      end

      def eb_env_name(stack_name, app_name, env_name)
        "#{env_name}-#{Digest::SHA1.hexdigest([stack_name, app_name].join)[0,10]}"
      end

      def solution_stack(template, stack_name, stack_configurations:)
        stack = stack_configurations.fetch(stack_name)
        stack_name = camelize(stack_name.gsub('-', '_').gsub(/[^A-Z0-9_]/i, ''))
        ami_selector = nil

        if amis = stack['ami']
          amis.each do |region, ami|
            template.add_to_region_mapping "StackAMIs", region, stack_name, ami
          end

          ami_selector = template.find_in_regional_mapping("StackAMIs", stack_name)
        end

        {name: stack.fetch('solution'),
         ami: ami_selector}
      end

      def extrapolate_backends(config, backends, template)
        config.inject({}) do |acc, (key, value)|
          if backend = value.to_s.match(BACKEND_REGEX)
            backend_output = backends[backend[:type]][backend[:name]].
                             output(template)

            acc[key] = backend_output.fetch(backend[:property])
          else
            acc[key] = value
          end
          acc
        end
      end
    end
  end
end
