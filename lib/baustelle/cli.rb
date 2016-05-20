require 'thor'
require 'baustelle'
require 'baustelle/ami/cli'
require "baustelle/script/cli"
require "baustelle/jenkins/cli"

module Baustelle
  class CLI < Thor
    class_option "region", desc: 'region where to run commands in',
                 default: ENV.fetch('AWS_DEFAULT_REGION', 'us-east-1')
    class_option "name", desc: 'name of the baustelle stack', default: 'baustelle'

    desc "create", "Create the baustelle according to specification in the yml file"
    option "specification", desc: 'path to the specification file',
           default: 'baustelle.yml'
    def create
      begin
        Baustelle::Commands::Create.call(specification_file, region: region,
                                       name: name)
        Baustelle::Commands::Jenkins::Seed.call(specification_file, region: region,
                                              name: name)
      ensure
        Baustelle::Commands::Wait.call(name: name, region: region)
      end

    end

    desc "update", "Update the baustelle according to specification in the yml file"
    option "specification", desc: 'path to the specification file',
           default: 'baustelle.yml'
    def update
      begin
        Baustelle::Commands::Update.call(specification_file, region: region,
                                       name: name)
        Baustelle::Commands::Jenkins::Seed.call(specification_file, region: region,
                                              name: name)
      ensure
        Baustelle::Commands::Wait.call(name: name, region: region)
      end

    end

    desc "delete", "Deletes the baustelle"
    option "specification", desc: 'path to the specification file',
           default: 'baustelle.yml'
    def delete
      Baustelle::Commands::Delete.call(name: name, region: region)
      Baustelle::Commands::Jenkins::Delete.call(specification_file, region: region,
                                              name: name)
      Baustelle::Commands::Wait.call(name: name, region: region)
    end

    desc "wait", "Waits for the baustelle to be ready"
    def wait
      Baustelle::Commands::Wait.call(name: name, region: region)
    end

    desc "read_config", "Prints configuration for every environment"
    option "specification", desc: 'path to the specification file',
           default: 'baustelle.yml'
    def read_config
      Baustelle::Commands::ReadConfig.call(specification_file)
    end

    desc "validate", "Validates the configuration"
    option "specification", desc: 'path to the specification file',
           default: 'baustelle.yml'
    def validate
      Baustelle::Commands::ValidateConfig.call(specification_file, region)
    end

    desc 'peer_vpc_config VPC_NAME', "Prints JSON CloudFormation template for peer VPC configuration"
    def peer_vpc_config(vpc_name)
      Aws.config[:region] = region

      template = Baustelle::CloudFormation::Template.new

      if peering_connection_id = Baustelle::CloudFormation::PeerVPC.
                                 list(name)[vpc_name.camelize]
        template.resource "VPC#{name.camelize}Route",
                          Type: 'AWS::EC2::Route',
                          Properties: {
                            DestinationCidrBlock: Baustelle::CloudFormation::VPC.cidr_block(name),
                            RouteTableId: "REPLACE WITH ROUTE TABLE ID REFERENCE",
                            VpcPeeringConnectionId: peering_connection_id
                          }
      end

      puts JSON.pretty_generate(template.as_json)

    end

    desc "ami SUBCOMMAND", "Manages AMI images"
    option "specification", desc: 'path to the specification file',
           default: 'baustelle.yml'
    subcommand "ami", AMI::CLI

    desc "jenkins SUBCOMMAND", "Manages related jenkins"
    option "specification", desc: 'path to the specification file',
           default: 'baustelle.yml'
    option "region", desc: 'region where to run commands in',
           default: ENV.fetch('AWS_DEFAULT_REGION', 'us-east-1')
    option "name", desc: 'name of the baustelle stack', default: 'baustelle'
    subcommand "jenkins", Jenkins::CLI

    desc "script SUBCOMMAND", "Scripts used for deployment in jenkins jobs"
    subcommand "script", Script::CLI

    private

    def specification_file
      options.fetch("specification")
    end

    def region
      options.fetch('region', ENV.fetch('AWS_DEFAULT_REGION', 'us-east-1'))
    end

    def name
      options.fetch('name', 'baustelle')
    end
  end
end
