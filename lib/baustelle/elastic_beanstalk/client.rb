require "baustelle/elastic_beanstalk/environment_configuration"

module Baustelle
  module ElasticBeanstalk
    class Client

      def initialize(region)
        Aws.config[:region] = region
        @eb = Aws::ElasticBeanstalk::Client.new
      end

      def info(env_name)
        result = @eb.describe_environments(environment_names: [env_name])
        envs = result.environments
        
        if envs.length == 0
          raise Thor::Error.new("No application found with name #{env_name}")
        else
          envs[0]
        end
      end

      def configuration(app_name, env_name)
        result = @eb.describe_configuration_settings(application_name: app_name,
                                                     environment_name: env_name)
        
        Baustelle::ElasticBeanstalk::EnvironmentConfiguration.new(result.configuration_settings[0])
      end

    end
  end
end
