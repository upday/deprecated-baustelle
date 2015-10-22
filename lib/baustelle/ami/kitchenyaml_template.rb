require 'yaml'

module Baustelle
  module AMI
    class KitchenTemplate

      def initialize(specification, ami:, region:)
        @specification = specification
        @ami = ami
        @region = region
        @yaml = <<KITCHEN_YML_SKELETON
---
driver:
  name: vagrant

verifier:
  ruby_bindir: '/usr/bin'

provisioner:
  name: shell

platforms:
  - name: ubuntu-aws
    driver_config:
      name: ec2
      image_id: none
      instance_type: m3.medium
      price: 0.05
      aws_ssh_key_id: mike.passberg
      region: eu-west-1
      availability_zone: eu-west-1c
      interface: public
      associate_public_ip: true
      retryable_tries: 100
      retryable_sleep: 10
      subnet_id: subnet-aefb7ed9
    transport:
      username: ubuntu
      ssh_key: ~/.ssh/aws

suites:
  - name: dummy

        
KITCHEN_YML_SKELETON
      end

      def valid?
        @ami && @region && File.exists?(playbook_path) && File.exists?(specification_path)
      end

      def generate(ssh_key:)
        yaml = YAML.load(@yaml)
        yaml["platforms"][0]["driver_config"]["image_id"] = @ami
        yaml["platforms"][0]["transport"]["ssh_key"] = ssh_key
        yaml["platforms"][0]["driver_config"]["aws_ssh_key_id"] = File.basename(ssh_key)
        yaml["suites"][0]["name"] = @specification
        yaml
      end

      private

      def playbook_path
        "ami/#{@specification}.yml"
      end

      def specification_path
        "ami/test/integration/#{@specification}"
      end

    end
  end
end
