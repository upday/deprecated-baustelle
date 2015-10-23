require 'jenkins_api_client'
require "baustelle/jenkins"

module Baustelle
  module Jenkins
    class CLI < Thor
      desc "seed NAME", "Create the seed job for given stack name"
      option :region, default: 'us-east-1'
      def seed(name)
        stack(name, options[:region]).update
      end

      desc "delete NAME", "Delete jobs for the stack from jenkins"
      option :region, default: 'us-east-1'
      def delete(name)
        stack(name, options[:region]).delete
      end

      private

      def specification
        Baustelle::Config.read(options[:specification])
      end

      def stack(name, region)
        Baustelle::Jenkins::Stack.new(name, config: specification,
                                      region: region)
      end
    end
  end
end
