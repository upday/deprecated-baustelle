require 'baustelle/ami'
require 'json'
require 'tempfile'

module Baustelle
  module AMI
    class CLI < Thor
      desc "list", "Lists available AMIs"
      def list
      end

      desc "build DEFINITION", "Builds an image"
      def build(definition)
        config = Baustelle::Config.read(specification_file).
                 fetch('base_amis').fetch(definition)

        base_ami = config.fetch(region)
        user = config.fetch('user')
        system = config.fetch('system')
        template = Baustelle::AMI::PackerTemplate.new(definition,
                                                      ami: base_ami,
                                                      region: region,
                                                      user: user,
                                                      system: system)
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
        parent_options.fetch("specification")
      end

      def region
        parent_options.fetch('region')
      end
    end
  end
end
