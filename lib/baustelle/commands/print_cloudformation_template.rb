require 'json'

module Baustelle
  module Commands
    module PrintCloudformationTemplate
      extend self

      def call(specification_file, region:, name:, application_stack_name: nil)
        config = Baustelle::Config.read(specification_file)
        template = Baustelle::StackTemplate.new(config).build(name, region, "baustelle-workspace-bucket")
        if application_stack_name
          template = template.childs[application_stack_name]
        end
        puts template.to_json
      end
    end
  end
end
