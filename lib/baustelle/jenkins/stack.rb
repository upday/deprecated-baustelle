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

              application_jobs.generate_jobs
            end
          end
        end
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
    end
  end
end
