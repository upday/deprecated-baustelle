require "baustelle/elastic_beanstalk/client"

module Baustelle
  module Script
    class CLI < Thor

      class_option "stack", desc: 'name of the baustelle stack', default: 'baustelle'

      desc "wait-until APPLICATION ENVIRONMENT ATTRIBUTE EXPECTED_VALUE",
           "Wait for an attribute of the application environment to match a certain value"
      long_desc <<-LONGDESC
        Common examples:
        \x5> baustelle script wait-until user_profile_service staging status Ready --stack yana --region eu-west-1
        \x5> baustelle script wait-until user_profile_service staging health Green --stack yana --region eu-west-1
      LONGDESC
      option "timeout", desc: "Max number of seconds to wait", default: 60, type: :numeric
      def wait_until(app_name, env_name, attribute, expected)
        eb = Baustelle::ElasticBeanstalk::Client.new(region)

        Timeout::timeout(options['timeout']) do
          loop do
            value = eb.info(app_name, env_name, stack_name)[attribute]
            puts("Application #{attribute} is #{value}")
            break if value == expected
            sleep(5)
          end
        end
      end

      desc "systemtest-env APPLICATION ENVIRONMENT",
           "Prints the environment variables that can be injected in jenkins systemtests jobs"
      long_desc <<-LONGDESC
        Example:
        \x5> baustelle script systemtests-env user_profile_service staging --stack yana --specification baustelle.yml --region eu-west-1
      LONGDESC
      option "specification", desc: 'path to the specification file', default: 'baustelle.yml'
      def systemtest_env(app_name, env_name)
        app_config = Baustelle::Config.read_app_config(specification_file, app_name, env_name)

        eb = Baustelle::ElasticBeanstalk::Client.new(region)
        env_config = eb.configuration(app_name, env_name, stack_name)
        env = env_config.env_vars

        config_from_app = ["APPLICATION_URL"] + app_config.raw.fetch('systemtests', {}).fetch('config_from_application_whitelist', [])
        env.delete_if { |k,v| !config_from_app.include?(k) }

        env['APPLICATION_URL'] ||= url(eb, app_config, app_name, env_name)

        # for backwards compatibility, deprecated
        env['HOST'] = env['APPLICATION_URL']

        env.each { |k,v| puts "#{k}=#{v}" }
      end


      private

      def url(eb, app_config, app_name, env_name)
        protocol = app_config.https? ? "https" : "http"
        if app_config.dns_name
          host = app_config.dns_name
        else
          host = eb.info(app_name, env_name, stack_name).cname
        end
        "#{protocol}://#{host}"
      end

      def specification_file
        options.fetch("specification")
      end

      def stack_name
        options.fetch('stack')
      end

      def region
        parent_options.fetch('region')
      end

    end
  end
end
