require 'json'

module Baustelle
  module Commands
    module Create
      extend self

      def call(specification_file, region:, name:)
        config = Baustelle::Config.read(specification_file)
        template = Baustelle::CloudFormation.build_template(config, name: name)

        Aws.config[:region] = region
        Baustelle::CloudFormation.create_stack(name, template) or exit(1)
        puts "Created stack #{name} in #{region}"
      end
    end
  end
end
