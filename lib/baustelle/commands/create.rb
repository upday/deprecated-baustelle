require 'json'

module Baustelle
  module Commands
    module Create
      extend self

      def call(specification_file, region:, name:)
        config = Baustelle::Config.read(specification_file)
        template = Baustelle::StackTemplate.new(config)

        Aws.config[:region] = region
        Baustelle::CloudFormation::RemoteTemplate.new(stack_name: name, region: region).
          call(template.to_json) do |template_url|
          Baustelle::CloudFormation.create_stack(name, template_url) or exit(1)
        end

        puts "Created stack #{name} in #{region}"
      end
    end
  end
end
