require "baustelle/jenkins"

module Baustelle
  module Jenkins
    class CLI < Thor
      desc "seed [--region=REGION] [--name=NAME]", "Create the seed job for given stack name"
      def seed
        Baustelle::Commands::Jenkins::Seed.call(options[:specification],
                                                region: options[:region],
                                                name: options[:name])
      end

      desc "delete  [--region=REGION] [--name=NAME]", "Delete jobs for the stack from jenkins"
      def delete
        Baustelle::Commands::Jenkins::Delete.call(options[:specification],
                                                  region: options[:region],
                                                  name: options[:name])
      end
    end
  end
end
