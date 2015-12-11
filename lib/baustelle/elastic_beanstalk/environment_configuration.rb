module Baustelle
  module ElasticBeanstalk
    class EnvironmentConfiguration

      def initialize(eb_configuration_settings)
        @options = eb_configuration_settings.option_settings
      end

      def env_vars
        env = @options.select { |opt| opt.namespace == "aws:elasticbeanstalk:application:environment" }
        env.each_with_object({}) { |opt,map| map[opt.option_name] = opt.value }
      end

    end
  end
end
