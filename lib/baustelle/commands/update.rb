require 'json'

module Baustelle
  module Commands
    module Update
      extend self

      def call(specification_file, region:, name:)
        config = Baustelle::Config.read(specification_file)
        template = Baustelle::StackTemplate.new(config).build(name)

        Aws.config[:region] = region
        Baustelle::CloudFormation.update_stack(name, template.to_json) or exit(1)
        puts "Updated stack #{name} in #{region}"
      end
    end
  end
end
