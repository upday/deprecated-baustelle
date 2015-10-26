require 'baustelle/ami'
require 'json'
require 'yaml'
require 'tempfile'
require 'aws-sdk'

module Baustelle
  module AMI
    class CLI < Thor

      desc "list", "Lists available AMIs"
      def list
        ""
      end

      desc "build DEFINITION", "Builds an image"
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

      desc "test AMI-ID SPEC", "Runs serverspec tests for specific AMI"
      def test(ami_id, specification)
        config = Baustelle::Config.read(specification_file)
        template = Baustelle::AMI::KitchenTemplate.new(specification, ami: ami_id, region: region)
        ec2 = Aws::EC2::Client.new(region: region)

        if template && template.valid?

          Tempfile.open("Baustelle") do |file|
            begin
              response = ec2.create_key_pair(key_name: File.basename(file.path))
              secret_key = response.key_material
              file.puts secret_key
              file.chmod(0600)
              file.close
  
              kitchen_yaml = template.generate(ssh_key: file.path).to_yaml
              kitchen_yaml_file = File.open(File.join("ami",".kitchen.yml"), "w")
              kitchen_yaml_file.puts kitchen_yaml
              kitchen_yaml_file.close
              
              Dir.chdir('ami') do
                exec "kitchen test"
              end
            ensure
              ec2.delete_key_pair(key_name: response.key_name)
            end
          end

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
