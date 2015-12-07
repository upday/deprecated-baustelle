require "baustelle/elastic_beanstalk/client"

module Baustelle
  module Script
    class CLI < Thor

      desc "wait-until-app ENVIRONMENT_NAME ATTRIBUTE EXPECTED_VALUE",
           "Wait for an attribute of the application environment to match a certain value"
      long_desc <<-LONGDESC
        Common examples:
        \x5> baustelle script wait-until-app staging-b3f3681be4 status Ready --region eu-west-1
        \x5> baustelle script wait-until-app staging-b3f3681be4 health Green --region eu-west-1
      LONGDESC
      option "timeout", desc: "Max number of seconds to wait", default: 60, type: :numeric
      def wait_until_app(env_name, attribute, expected)
        eb = Baustelle::ElasticBeanstalk::Client.new(region())

        Timeout::timeout(options['timeout']) do
          loop do
            value = eb.info(env_name)[attribute]
            puts("Application #{attribute} is #{value}")
            break if value == expected
            sleep(5)
          end
        end
      end

      desc "systemtests-env APPLICATION_NAME ENVIRONMENT_NAME",
           "Prints the environment variables that can be injected in jenkins systemtests jobs"
      option "alternate-dns", desc: "Alternate dns name instead of using the <app>.elasticbeanstalk.com domain as HOST variable"
      def systemtests_env(app_name, env_name)
        eb = Baustelle::ElasticBeanstalk::Client.new(region())

        env_config = eb.configuration(app_name, env_name)
        env = env_config.env_vars()

        # remove environment variables that break the jenkins build
        env.delete_if { |k,v| k.start_with?("M2") || k.start_with?("JAVA_HOME") }

        env['APPLICATION_URL'] = url(eb, env_name, env_config)
        # for backwards compatibility, deprecated
        env['HOST'] = env['APPLICATION_URL']

        env.each { |k,v| puts "#{k}=#{v}" }
      end


      private

      def url(eb, env_name, env_config)
        protocol = env_config.protocol()
        host = options['alternate-dns'] || eb.info(env_name).cname
        "#{protocol}://#{host}"
      end

      def region()
        options.fetch("region", ENV.fetch("AWS_DEFAULT_REGION", "us-east-1"))
      end
      
    end
  end
end
