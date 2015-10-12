require 'baustelle/ami'
require 'json'
require 'tempfile'

module Baustelle
  module AMI
    class CLI < Thor
      class_option "region", desc: 'region where to run commands in',
                   default: ENV.fetch('AWS_DEFAULT_REGION', 'us-east-1')
      desc "list", "Lists available AMIs"
      def list
      end

      desc "build DEFINITION", "Builds an image"
      option "specification", desc: 'path to the specification file',
             default: 'baustelle.yml'
      def build(definition)
        config = Baustelle::Config.read(specification_file)
        base_ami = config.fetch('base_ami')[region]
        template = Baustelle::AMI::PackerTemplate.new(definition,
                                                         ami: base_ami,
                                                         region: region)
        if template && template.valid?
          Tempfile.open("template.json") do |file|
            file.puts template.as_json.to_json
            file.close
            exec "packer build #{file.path}"
          end
        else
          exit(false)
        end
      end

      private

      def specification_file
        options.fetch("specification", "baustelle.yml")
      end

      def region
        options.fetch('region', ENV.fetch('AWS_DEFAULT_REGION', 'us-east-1'))
      end
    end
  end
end
