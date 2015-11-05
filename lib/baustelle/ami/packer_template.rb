require 'base64'

module Baustelle
  module AMI
    class PackerTemplate
      def initialize(definition, ami:, region:, user: 'ubuntu',
                     system: 'ubuntu', user_data:)
        @definition = definition
        @ami = ami
        @region = region
        @user = user
        @system = system
        @user_data = user_data
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
              associate_public_ip_address: true,
              tags: {
                "BaustelleImage" => @definition
              },
              user_data: Base64.encode64(@user_data.to_s)
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
            "sudo apt-add-repository ppa:ansible/ansible -y",
            "sudo apt-get update",
            "sudo apt-get install -y ansible",
          ]
        when 'amazon'
          [
            "sudo pip install ansible --upgrade",
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
