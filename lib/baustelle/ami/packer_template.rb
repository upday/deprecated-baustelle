module Baustelle
  module AMI
    class PackerTemplate
      def initialize(definition, ami:, region:, user: 'ubuntu', system: 'ubuntu')
        @definition = definition
        @ami = ami
        @region = region
        @user = user
        @system = system
      end

      def valid?
        @ami && @region && File.exists?(playbook_path)
      end

      def as_json
        {
          builders: [
            {
              type: "amazon-ebs",
              access_key: "",
              secret_key: "",
              region: "#{@region}",
              source_ami: "#{@ami}",
              instance_type: "m4.large",
              ssh_username: @user,
              ssh_pty: true,
              ami_name: "baustelle-#{@definition}-#{Time.now.strftime('%Y%m%d%H%M%S')}",
              ami_description: "Baustelle Image #{@definition}",
              tags: {
                "BaustelleImage" => @definition
              }
            }
          ],
          provisioners: [
            {
              type: "shell",
              inline: install_ansible(@system)
            },
            {
              type: "ansible-local",
              playbook_dir: "ami",
              playbook_file: playbook_path
            }
          ]
        }
      end

      private

      def install_ansible(system)
        case system
        when 'ubuntu'
          [
            "sudo apt-get install -y software-properties-common",
            "sudo apt-add-repository ppa:ansible/ansible",
            "sudo apt-get update",
            "sudo apt-get install -y ansible",
          ]
        when 'amazon'
          [

          ]
        else
          raise "Unsupported base system"
        end
      end

      def playbook_path
        "ami/#{@definition}.yml"
      end
    end
  end
end
