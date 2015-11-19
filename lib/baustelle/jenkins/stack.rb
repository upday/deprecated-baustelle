require 'jenkins_api_client'
require 'baustelle/cloud_formation/ebenvironment'

module Baustelle
  module Jenkins
    class Stack
      include Baustelle::Camelize

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
        jenkins.view.create_list_view(name: "Baustelle #{name} (#{region})",
                                      regex: "baustelle-#{name}-#{region}-.*")
        Baustelle::Config.for_every_environment(config) do |environment, _|
          jenkins.view.create_list_view(name: "Baustelle #{name} (#{region}) #{environment} DEPLOY",
                                        regex: "baustelle-#{name}-#{region}-#{environment}-.*-00-deploy")
        end
      end

      def delete_views
        views = jenkins.view.list("Baustelle #{name}.*#{region}.*")
        views.each { |view| jenkins.view.delete(view) }
      end


      def create_jobs
        Baustelle::Config.for_every_environment(config) do |environment, env_config|
          Baustelle::Config.for_every_application(env_config) do |application, app_config|
            unless app_config.fetch('disabled', false)
              job_name_prefix = "baustelle-#{name}-#{region}-#{environment}-#{application}-"
              template = Baustelle::Jenkins::JobTemplate.new(
                File.read("jobs/#{app_config['stack']}.groovy.erb"),
                {
                  app_config: app_config,
                  jenkins_options: jenkins_options,
                  region: @region,
                  eb_environment_name: Baustelle::CloudFormation::EBEnvironment.
                    eb_env_name(@name, application, environment),
                  eb_application_name: camelize("#{@name}-#{application}".gsub('-', '_')),
                  eb_application_version_source: env_config.fetch('eb_application_version_source', NIL)
                }
              )

              jobs = template.render(prefix: job_name_prefix)

              jobs.select { |name, _| name =~/^#{job_name_prefix}-\d+-.*/ }.
                each do |job_name, xml|
                jenkins.job.create_or_update(job_name, xml)
              end

              jenkins.job.chain(jobs.keys.sort, 'success', ['all'])






              @generated_jobs.merge!(jobs)
            end
          end
        end
      end


      def cleanup_jobs
        jobs_to_delete = (jenkins.job.list("^baustelle-#{name}-#{region}") -
                          @generated_jobs.keys)
        jobs_to_delete.each { |job| jenkins.job.delete(job) }
      end
    end
  end
end
