require 'json'

module Baustelle
  module Commands
    module Create
      extend self

      def call(specification_file, region:, name:)
        config = Baustelle::Config.read(specification_file)
        template = Baustelle::StackTemplate.new(config).build(name)

        Aws.config[:region] = region
        Baustelle::CloudFormation.create_stack(name, template.to_json) or exit(1)
        puts "Created stack #{name} in #{region}"
      end
    end
  end
end
