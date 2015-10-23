require "baustelle/jenkins"

module Baustelle
  module Commands
    module Jenkins
      module Seed
        extend self

        def call(specification_file, region:, name:)
          config = Baustelle::Config.read(specification_file)
          Aws.config[:region] = region
          Baustelle::Jenkins::Stack.new(name, region: region, config: config).
            update
          puts "Updated jenkins jobs for #{name} stack in #{region}"
        end
      end
    end
  end
end
