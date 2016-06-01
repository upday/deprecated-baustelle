require 'rschema/aws_instance_type'
require 'rschema/aws_autoscaling_trigger'

module Baustelle
  module Config
    module Validator
      class Application

        class ConfigEntry
          def initialize(applications:, backends:)
            @applications = applications
            @backends = backends
          end

          def schema_walk(value, mapper)
            if match = Baustelle::CloudFormation::EBEnvironment::BACKEND_REGEX.match(value.to_s)
              unless @backends.fetch(type = match['type'], {}).
                fetch(name = match['name'], nil)
                RSchema::ErrorDetails.new(value, "#{type}:#{name} is not defined as backend in backends section")
              end
            elsif match = Baustelle::CloudFormation::EBEnvironment::APPLICATION_REF_REGEX.match(value.to_s)
              unless @applications.include?(name = match['name'])
                RSchema::ErrorDetails.new(value, "#{name} is not defined as an application")
              end
            else
              value
            end
          end
        end

        include RSchema::DSL::Base
        
        def initialize(full_config)
          @full_config = full_config
        end

        def schema
          {
            'git' => git = {
              'repo' => String,
              optional('branch') => String
            },
            'stack' => enum(stacks),
            'scale' => {
              'min' => Fixnum,
              'max' => Fixnum
            },
            # https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html#command-options-general-autoscalingtrigger
            optional('trigger') => {
              'measure_name' => enum(RSchema::AWSAutoscalingTriggers::MEASURES),
              'lower_threshold' => Fixnum,
              'upper_threshold' => Fixnum
            },
            'instance_type' => instance_type,
            'config' => hash_of(
              String => ConfigEntry.new(applications: applications,
                                        backends: backends)
            ),
            optional('hostname_scheme') => enum(%w(old new)),
            optional('disabled') => boolean,
            optional('pre_deploy_test_command') => String,
            optional('systemtests') => either(enum(applications),
                                              FalseClass, NilClass,
                                              {
                                                'git' => git,
                                                optional('command') => String,
                                                optional('cron') => String,
                                                optional('config_from_application_whitelist') => [String],
                                                optional('maven') => hash_of(String => String)
                                              }),
            optional('elb') => {
              optional('https') => boolean,
              optional('ssl_certificate') => predicate("is a ARN resource of a server certificate") { |value| value =~ /^arn:aws:iam::\d+:server-certificate\/.*/ },
              optional('ssl_reference_policy') => String,
              optional('visibility') => enum(%w(internal external)),
              optional('keep_http_listener') => boolean
            },
            optional('dns') =>{
              'hosted_zone' => String,
              'name' => String
            },
            optional('maven') => Hash,
            optional('procfile') => {
              optional('command_line_params') => String
            },
            optional('iam_instance_profile') => hash_of(
              String => {
                optional('effect') => enum(%w(Allow Deny)),
                optional('resource') => either(String, [String]),
                'action' => either(String, [String])
              }
            ),
            optional('new_environment_naming') => boolean,
            optional('miscellaneous') => Hash,
          }
        end

        private

        def applications
          @full_config.fetch('environments', {}).
            inject(@full_config.fetch('applications', {}).keys) do |applications, (_, environment)|

            applications + environment.fetch('applications', {}).keys
          end.uniq
        end

        def backends
          @full_config.fetch('environments', {}).
            inject(@full_config.fetch('backends', {})) do |backends, (_, environemnt)|

            backends.deep_merge(environemnt.fetch('backends', {}))
          end
        end


        def stacks
          @full_config.fetch('stacks', {}).keys
        end
      end
    end
  end
end
