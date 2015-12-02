require 'jenkins_api_client'
require 'baustelle/cloud_formation/ebenvironment'

module Baustelle
  module Jenkins
    class ApplicationJob
      @@identifier = "baustelle"
      def initialize(name, region, jenkins_options, environment, application, app_config, eb_application_version_source)
        @environment = environment
        @application = application
        @jenkins_options = jenkins_options
        @app_config = app_config
        @name = name
        @region = region
        @eb_application_version_source = eb_application_version_source

        @job_name_prefix = "#{@@identifier}-#{@name}-#{@region}-#{@environment}-#{@application}-"
        @templates = {
          :systemtests => "jobs/#{app_config['stack']}.systemtests.groovy.erb",
          :pipeline => "jobs/#{app_config['stack']}.groovy.erb"
        }
      end

      def generate_system_tests
        if @app_config.key?('systemtests') && @app_config.fetch('systemtests', false)
          create_template(
            @templates[:systemtests]
          )
        else
          {}
        end
      end

      def generate_pipeline
        create_template(
          @templates[:pipeline],
          systemtest_job_name(@app_config.fetch('systemtests', {}))
        )
      end

      def systemtest_job_name(systemtests_config)
        if systemtests_config.is_a? Hash
          "#{@job_name_prefix}systemtests"
        else
          "#{@@identifier}-#{@name}-#{@region}-#{@environment}-#{@application}-#{systemtests_config}-systemtests"
        end
      end

      def create_template(template_file, system_test_job_name='')
        template = Baustelle::Jenkins::JobTemplate.new(
          template_file,
          {
            stack_name: @name,
            app_config: @app_config,
            jenkins_options: @jenkins_options,
            region: @region,
            eb_environment_name: Baustelle::CloudFormation::EBEnvironment.
              eb_env_name(@name, @application, @environment),
            eb_application_name: "#{@name}-#{@application}".gsub('-', '_').underscore.camelize,
            eb_application_version_source: @eb_application_version_source,
            endpoint: "#{@name}-#{@region}-#{@environment}-#{@application}.elasticbeanstalk.com".gsub('_', '-'),
            system_test_job_name: system_test_job_name
          }
        )
        template.render(prefix: @job_name_prefix)
      end
    end
  end
end
