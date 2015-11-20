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

        eb_dns = template.join('-', stack_name,
                               template.ref('AWS::Region'),
                               "#{env_name}-#{app_name}".gsub('_', '-'))

        template.resource resource_name = "#{camelize(app_name)}Env#{camelize(env_name)}",
                          Type: "AWS::ElasticBeanstalk::Environment",
                          Properties: {
                            ApplicationName: app_ref,
                            CNAMEPrefix: eb_dns,
                            EnvironmentName: env_hash,
                            SolutionStackName: stack.fetch(:name),
                            Tags: [
                              { 'Key' => 'FQN',         'Value' => "#{app_name}.#{env_name}.#{stack_name}" },
                              { 'Key' => 'Application', 'Value' => app_name },
                              { 'Key' => 'Stack',       'Value' => stack_name },
                              { 'Key' => 'Environment', 'Value' => env_name },
                            ],
                            OptionSettings: {
                              'aws:autoscaling:launchconfiguration' => {
                                'EC2KeyName' => 'kitchen',
                                'IamInstanceProfile' => template.ref('IAMInstanceProfile'),
                                'InstanceType' => app_config.fetch('instance_type')
                              },
                              'aws:autoscaling:updatepolicy:rollingupdate' => {
                                'RollingUpdateEnabled' => 'true',
                                'RollingUpdateType' => 'Health'
                              },
                              'aws:autoscaling:asg' => {
                                'MinSize' => app_config.fetch('scale').fetch('min'),
                                'MaxSize' => app_config.fetch('scale').fetch('max')
                              },
                              'aws:ec2:vpc' => {
                                'VPCId' => vpc.id,
                                'Subnets' => template.join(',', *vpc.zone_identifier),
                                'ELBSubnets' => template.join(',', *vpc.zone_identifier),
                                'AssociatePublicIpAddress' => 'true',
                                'ELBScheme' => app_config.fetch('elb', {}).
                                              fetch('visibility', 'external')
                              },
                              'aws:elasticbeanstalk:application' => {
                                'Application Healthcheck URL' => '/health'
                              },
                              'aws:elasticbeanstalk:command' => {
                                'BatchSize' => 1,
                                'BatchSizeType' => 'Fixed'
                              },
                              'aws:elb:loadbalancer' => {
                                'CrossZone' => true
                              },
                              'aws:elb:healthcheck' => {
                                'Interval' => 10,
                                'Timeout' => 5,
                                'HealthyThreshold' => 2,
                                'UnhealthyThreshold' => 2
                              },
                              'aws:elb:policies' => {
                                'ConnectionDrainingEnabled' => true,
                                'ConnectionDrainingTimeout' => 20,
                              },
                              'aws:elasticbeanstalk:application:environment' => EBEnvironment.extrapolate_backends(app_config.fetch('config', {}),
                                                                                                                   backends, template)
                            }.tap do |settings|
                              if ami = stack.fetch(:ami)
                                settings['aws:autoscaling:launchconfiguration']['ImageId'] = ami
                              end

                              EBEnvironment.configure_elb_protocol(settings, app_config.fetch('elb', {}))
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
        template.ref(resource_name)
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

      def configure_elb_protocol(settings, elb)
        # nothing to do if https is not desired (= HTTP), we rely on the default listener that is autogenerated by elasticbeanstalk
        return unless elb.fetch('https', false)

        # we only want https enabled. Therefore the default listener that is generated by elasticbeanstalk has to be disabled
        settings['aws:elb:listener:80'] = {
          'ListenerEnabled' => 'false'
        }

        settings['aws:elb:listener:443'] = {
          'ListenerProtocol' => 'HTTPS',
          'InstanceProtocol' => 'HTTP',
          'InstancePort' => '80',
          'SSLCertificateId' => elb['ssl_certificate'],
          'PolicyNames' => 'SSL'  # matches with the policy name defined below
        }

        # AWS predefined SSL policy that only enables the SSL ciphers that are safe to use
        settings['aws:elb:policies:SSL'] = {
          'SSLReferencePolicy' => elb['ssl_reference_policy']
        }
      end

      def extrapolate_backends(config, backends, template)
        config.inject({}) do |acc, (key, value)|
          if backend = value.to_s.match(BACKEND_REGEX)
            backend_output = backends[backend[:type]][backend[:name]].
                             output(template)

            # TODO: more readable error message
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
