require 'jenkins_api_client'
require 'baustelle/cloud_formation/ebenvironment'

module Baustelle
  module Jenkins
    class Stack
      def initialize(name, config:, region:)
        @name = name
        @config = config
        @region = region
        @generated_jobs = {}
      end

      def update
        create_jobs
        cleanup_jobs
        delete_views
        create_views
      end

      def delete
        cleanup_jobs
        delete_views
      end

      private

      attr_reader :jenkins, :name, :config, :region

      def jenkins
        @jenkins ||= JenkinsApi::Client.new(**jenkins_config)
      end

      def jenkins_config
        config.fetch("jenkins").fetch("connection").
          inject({}) { |acc, (k,v)| acc[k.to_sym] = v; acc }
      end

      def jenkins_options
        config.fetch("jenkins").fetch("options").
          inject({}) { |acc, (k,v)| acc[k.to_s] = v; acc }
      end

      def create_views
        jenkins.view.create_list_view(name: "Baustelle #{@name} (#{@region})",
                                      regex: "baustelle-#{@name}-#{@region}-.*")
        Baustelle::Config.for_every_environment(config) do |environment, _|
          jenkins.view.create_list_view(name: "Baustelle #{@name} (#{@region}) #{environment} DEPLOY",
                                        regex: "baustelle-#{@name}-#{@region}-#{environment}-.*-00-deploy")
        end
      end

      def delete_views
        views = jenkins.view.list("Baustelle #{@name}.*#{@region}.*")
        views.each { |view| jenkins.view.delete(view) }
      end


      def create_jobs
        Baustelle::Config.for_every_environment(@config) do |environment, env_config|
          Baustelle::Config.for_every_application(env_config) do |application, app_config|
            unless app_config.fetch('disabled', false)
              job_name_prefix = "baustelle-#{@name}-#{@region}-#{environment}-#{application}-"
              systemtest_job_name = create_systemtests(environment, env_config, application, app_config, job_name_prefix)
              create_pipeline(environment, env_config, application, app_config, job_name_prefix, systemtest_job_name)
            end
          end
        end
      end

      def create_template(environment, env_config, application, app_config, template_file, job_name_prefix, system_test_job_name='')
        template_file = template_file || "jobs/#{app_config['stack']}.groovy.erb"
        template = Baustelle::Jenkins::JobTemplate.new(
          template_file,
          {
            stack_name: @name,
            app_config: app_config,
            jenkins_options: jenkins_options,
            region: @region,
            eb_environment_name: Baustelle::CloudFormation::EBEnvironment.
              eb_env_name(@name, application, environment),
            eb_application_name: "#{@name}-#{application}".gsub('-', '_').underscore.camelize,
            eb_application_version_source: env_config.fetch('eb_application_version_source', 'git'),
            endpoint: "#{@name}-#{@region}-#{environment}-#{application}.elasticbeanstalk.com".gsub('_', '-'),
            system_test_job_name: system_test_job_name
          }
        )
        template.render(prefix: job_name_prefix)
      end

      def upload_jobs(jobs)
        jobs.each do |job_name, xml|
          jenkins.job.create_or_update(job_name, xml)
        end
      end

      def create_pipeline(environment, env_config, application, app_config, job_name_prefix, system_test_job_name)

        jobs = create_template(
          environment,
          env_config,
          application,
          app_config,
          "jobs/#{app_config['stack']}.groovy.erb",
          job_name_prefix,
          system_test_job_name
        )
        upload_jobs(jobs)
        jobs_to_chain = jobs.keys.grep(/^#{job_name_prefix}\d+-.*/).sort
        jenkins.job.chain(jobs_to_chain, 'success', ['all'])
        @generated_jobs.merge!(jobs)
      end

      def create_systemtests(environment, env_config, application, app_config, job_name_prefix)
        jobs = create_template(
          environment,
          env_config,
          application,
          app_config,
          "jobs/#{app_config['stack']}.systemtests.groovy.erb",
          job_name_prefix
        )
        upload_jobs(jobs)
        jobs.keys.first
      end


      def cleanup_jobs
        jobs_to_delete = (jenkins.job.list("^baustelle-#{@name}-#{@region}") -
                          @generated_jobs.keys)
        jobs_to_delete.each { |job| jenkins.job.delete(job) }
      end
    end
  end
end
