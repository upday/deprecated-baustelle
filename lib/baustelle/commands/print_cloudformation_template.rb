require 'json'

module Baustelle
  module Commands
    module PrintCloudformationTemplate
      extend self

      def call(specification_file, region:, name:)
        config = Baustelle::Config.read(specification_file)
        template = Baustelle::StackTemplate.new(config).build(name, region, "baustelle-workspace-bucket")

        puts template.to_json
      end
    end
  end
end
