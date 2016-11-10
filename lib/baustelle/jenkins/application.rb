require 'jenkins_api_client'
require 'baustelle/cloud_formation/ebenvironment'

module Baustelle
  module Jenkins
    class ApplicationJobs
      def initialize(stack_name, region, jenkins_options, environment, application, app_config, application_version_source)
        @environment = environment
        @application = application
        @jenkins_options = jenkins_options
        @app_config = app_config
        @name = stack_name
        @region = region
        @application_version_source = application_version_source
      end

      def generate_jobs
        if should_generate_systemtests?
          generate_systemtests
        end
          generate_pipeline
      end

      def identifier
        "baustelle"
      end

      def job_name_prefix
        "#{identifier}-#{@name}-#{@region}-#{@environment}-#{@application}-"
      end

      def template_file(template_type)
        {
          :systemtests => "jobs/#{@app_config.raw['stack']}.systemtests.groovy.erb",
          :pipeline => "jobs/#{@app_config.raw['stack']}.groovy.erb"
        }[template_type]
      end

      def should_generate_systemtests?
        @app_config.raw.fetch('systemtests', false).is_a?(Hash)
      end

      private

      def generate_systemtests
        create_template(
          template_file(:systemtests)
        )
      end

      def generate_pipeline
        create_template(
          template_file(:pipeline),
          systemtest_job_name(@app_config.raw.fetch('systemtests', {}))
        )
      end

      def systemtest_job_name(systemtests_config)
        if systemtests_config.is_a? Hash
          "#{job_name_prefix}systemtests"
        else
          "#{identifier}-#{@name}-#{@region}-#{@environment}-#{systemtests_config}-systemtests"
        end
      end

      def create_template(template_file, system_test_job_name='systemtests')
        template = Baustelle::Jenkins::JobTemplate.new(
          File.read(template_file),
          File.dirname(template_file),
          {
            stack_name: @name,
            app_name: @application,
            app_config: @app_config.raw,
            jenkins_options: @jenkins_options,
            region: @region,
            eb_environment_name: Baustelle::CloudFormation::EBEnvironment.
              eb_env_name(@name, @application, @environment),
            eb_application_name: "#{@name}-#{@application}".gsub('-', '_').underscore.camelize,
            application_version_source: @application_version_source,
            system_test_job_name: system_test_job_name
          }
        )
        template.render(prefix: job_name_prefix)
      end

    end
  end
end
