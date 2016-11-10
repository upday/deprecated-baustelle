require 'json'

module Baustelle
  module Commands
    module GenerateJobs
      extend self

      def call(specification_file, region:, name:)
        config = Baustelle::Config.read(specification_file)
        Aws.config[:region] = region
        Baustelle::Jenkins::Stack.new(name, region: region, config: config).create_jobs
        puts "Updated jenkins jobs for #{name} stack in #{region}"
      end
    end
  end
end
