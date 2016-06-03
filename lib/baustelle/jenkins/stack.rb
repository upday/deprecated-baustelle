require 'jenkins_api_client'
require 'baustelle/cloud_formation/ebenvironment'
require 'baustelle/jenkins/application'

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
      def capitalize_app_name(application_name)
        application_name.gsub(/_/, ' ').split.map(&:capitalize).join(' ')
      end

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

      public
      def create_views
        jenkins.view.create_list_view(name: "Baustelle #{@name} (#{@region})",
                                      regex: "baustelle-#{@name}-#{@region}-.*")
        Baustelle::Config.for_every_environment(config) do |environment, _|
          jenkins.view.create_list_view(name: "Baustelle #{@name} (#{@region}) #{environment} DEPLOY",
                                        regex: "baustelle-#{@name}-#{@region}-#{environment}-.*-00-deploy")
        end
        Baustelle::Config.for_every_application(config) do |application, _|
          jenkins.view.create_list_view(name: "Baustelle #{capitalize_app_name(application)}",
                                        regex: "Baustelle .* #{application} .*")
        end
      end

      private
      def delete_views
        views = jenkins.view.list("Baustelle #{@name}.*#{@region}.*")
        Baustelle::Config.for_every_application(config) do |application, _|
          views =+ jenkins.view.list("Baustelle .* #{capitalize_app_name(application)}")
        end
        views.each { |view| jenkins.view.delete(view) }

      end


      def create_jobs
        Baustelle::Config.for_every_environment(@config) do |environment, env_config|
          Baustelle::Config.for_every_application(env_config) do |application, app_config|
            unless app_config.disabled?
              application_jobs = Baustelle::Jenkins::ApplicationJobs.new(
                @name,
                @region,
                jenkins_options,
                environment,
                application,
                app_config,
                env_config.fetch('eb_application_version_source', 'git')
              )

              jobs = application_jobs.generate_jobs
              upload_jobs(jobs)
              jobs_to_chain = jobs.keys.grep(/^#{application_jobs.job_name_prefix}\d+-.*/).sort
              jenkins.job.chain(jobs_to_chain, 'success', ['all'])

              @generated_jobs.merge!(jobs)
            end
          end
        end
      end

      def upload_jobs(jobs)
        jobs.each do |job_name, xml|
          jenkins.job.create_or_update(job_name, xml)
        end
      end


      def cleanup_jobs
        jobs_to_delete = (jenkins.job.list("^baustelle-#{@name}-#{@region}") -
                          @generated_jobs.keys)
        jobs_to_delete.each { |job| jenkins.job.delete(job) }
      end
    end
  end
end
