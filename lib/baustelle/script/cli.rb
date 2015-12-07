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
      option "timeout", desc: "Max number of seconds to wait", default: 60
      def wait_until_app(env_name, attribute, expected)
        Timeout::timeout(options["timeout"]) do
          loop do
            value = describe_environment(env_name)[attribute]
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
        env = env_vars(app_name, env_name)

        # remove environment variables that break the jenkins build
        env.delete_if { |k,v| k.start_with?("M2") || k.start_with?("JAVA_HOME") }

        # set hostname where the application is running on
        env['HOST'] = options['alternate-dns'] || describe_environment(env_name).cname

        env.each { |k,v| puts "#{k}=#{v}" }
      end


      private

      def describe_environment(env_name)
        result = eb().describe_environments(environment_names: [env_name])
        envs = result.environments
        
        if envs.length() == 0
          raise Thor::Error.new("No application found with name #{env_name}")
        else
          envs[0]
        end
      end

      def env_vars(app_name, env_name)
        result = eb().describe_configuration_settings(application_name: app_name,
                                                      environment_name: env_name)
        opts = result.configuration_settings[0].option_settings
        opts = opts.select { |o| o.namespace == "aws:elasticbeanstalk:application:environment" }
        opts.each_with_object({}) { |opt,map| map[opt.option_name] = opt.value }
      end

      def eb()
        Aws.config[:region] = options.fetch("region", ENV.fetch("AWS_DEFAULT_REGION", "us-east-1"))
        Aws::ElasticBeanstalk::Client.new()
      end
    end
  end
end
