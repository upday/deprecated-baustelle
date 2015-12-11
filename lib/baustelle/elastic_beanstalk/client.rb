require "baustelle/elastic_beanstalk/environment_configuration"

module Baustelle
  module ElasticBeanstalk
    class Client

      def initialize(region)
        Aws.config[:region] = region
        @region = region
        @eb = Aws::ElasticBeanstalk::Client.new
      end

      def info(app_name, env_name, stack_name)
        eb_env_name = eb_environment_name(app_name, env_name, stack_name)
        result = @eb.describe_environments(environment_names: [eb_env_name])
        envs = result.environments
        
        if envs.length == 0
          raise Thor::Error.new("No application found with name #{app_name} " +
                                "on environment #{env_name} of stack #{stack_name} in region #{@region}")
        else
          envs[0]
        end
      end

      def configuration(app_name, env_name, stack_name)
        result = @eb.describe_configuration_settings(
            application_name: eb_application_name(app_name, stack_name),
            environment_name: eb_environment_name(app_name, env_name, stack_name))
        
        Baustelle::ElasticBeanstalk::EnvironmentConfiguration.new(result.configuration_settings[0])
      end


      private

      def eb_application_name(app_name, stack_name)
        Baustelle::CloudFormation::Application.eb_name(stack_name, app_name)
      end

      def eb_environment_name(app_name, env_name, stack_name)
        Baustelle::CloudFormation::EBEnvironment.eb_env_name(stack_name, app_name, env_name)
      end

    end
  end
end
