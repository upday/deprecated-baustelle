require 'jenkins_api_client'
require "baustelle/jenkins"

module Baustelle
  module Jenkins
    class CLI < Thor
      desc "bootstrap", "Ensures that all plugins are installed"
      def bootstrap
        new_plugin = false
        unless client.plugin.list_installed.keys.include?("job-dsl")
          client.plugin.install "job-dsl"
          new_plugin = true
        end

        unless client.plugin.list_installed.keys.include?("git")
          client.plugin.install "git"
          new_plugin = true
        end

        if new_plugin
          sleep 1 until client.plugin.restart_required?
          client.system.restart
          puts "After restart jenkins will be ready"
        end
      end

      desc "seed NAME", "Create the seed job for given stack name"
      option :credentials_id, default: nil
      option :region, default: 'us-east-1'
      def seed(name)
        stack = Baustelle::Jenkins::Stack.new(name, config: specification,
                                              options: options)
        stack.update
      end

      private

      def specification
        Baustelle::Config.read(options[:specification])
      end
    end
  end
end
