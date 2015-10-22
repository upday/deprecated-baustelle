module Baustelle
  module Jenkins
    class Stack
      def initialize(name, config:, options: {})
        @name = name
        @config = config
        @options = options
        @generated_jobs = {}
      end

      def update
        create_jobs
        cleanup_jobs
      end

      private

      attr_reader :jenkins, :name, :config

      def jenkins
        @jenkins ||= JenkinsApi::Client.new(**jenkins_config)
      end

      def jenkins_config
        config.fetch("jenkins").inject({}) { |acc, (k,v)| acc[k.to_sym] = v; acc }
      end

      def create_jobs
        Baustelle::Config.for_every_environment(config) do |environment, env_config|
          Baustelle::Config.for_every_application(env_config) do |application, app_config|
            job_name_prefix = "baustelle-#{name}-#{environment}-#{application}-"
            p app_config
            template = Baustelle::Jenkins::JobTemplate.new(
              File.read("jobs/#{app_config['stack']}.groovy.erb"),
              {
                app_config: app_config
              }
            )

            jobs = template.render(prefix: job_name_prefix)

            jobs.each do |job_name, xml|
              jenkins.job.create_or_update(job_name, xml)
            end

            jenkins.job.chain(jobs.keys.sort, 'success', ['all'])

            @generated_jobs.merge!(jobs)
          end
        end
      end

      def cleanup_jobs
        jobs_to_delete = (jenkins.job.list("^baustelle-#{name}") -
                          @generated_jobs.keys)
        jobs_to_delete.each { |job| jenkins.job.delete(job) }
      end
    end
  end
end
