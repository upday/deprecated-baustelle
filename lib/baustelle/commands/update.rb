require 'json'

module Baustelle
  module Commands
    module Update
      extend self

      def call(specification_file, region:, name:)
        config = Baustelle::Config.read(specification_file)
        template = Baustelle::CloudFormation.build_template(config, name: name)

        Aws.config[:region] = region
        Baustelle::CloudFormation.update_stack(name, template) or exit(1)
        puts "Updated stack #{name} in #{region}"
      end
    end
  end
end
