require 'json'

module Platform
  module Commands
    module Create
      extend self

      def call(specification_file, region:, name:)
        config = Platform::Config.read(specification_file)
        template = Platform::CloudFormation.build_template(config, name: name)

        Aws.config[:region] = region
        Platform::CloudFormation.create_stack(name, template) or exit(1)
        puts "Created stack #{name} in #{region}"
      end
    end
  end
end
