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

      def protocol
        option = @options.detect { |opt| opt.namespace == "aws:elb:policies:SSL" && opt.option_name == 'LoadBalancerPorts' }
        # we do not support other ports than 443 for now, so this is safe:
        if option && option.value == '443'
          "https"
        else
          "http"
        end
      end

    end
  end
end
