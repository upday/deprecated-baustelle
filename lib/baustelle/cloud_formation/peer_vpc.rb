module Baustelle
  module CloudFormation
    module PeerVPC
      extend self

      OUTPUT_REGEX = /PeeringConnectionVPC(.*)/

      def apply(template, vpc, peer_name, peer_config)
        prefix = "PeerVPC#{peer_name.camelize}"
        peering_connection_id = "#{prefix}PeeringConnection"
        template.resource peering_connection_id,
                          Type: "AWS::EC2::VPCPeeringConnection",
                          Properties: {
                            VpcId: vpc.id,
                            PeerVpcId: peer_config.fetch('vpc_id'),
                            Tags: [
                              {Key: 'Name', Value: "#{vpc.name}-to-#{peer_name}"}
                            ]
                          }

        template.resource "#{prefix}Route",
                          Type: 'AWS::EC2::Route',
                          Properties: {
                            DestinationCidrBlock: peer_config.fetch('cidr'),
                            RouteTableId: template.ref("#{vpc.name}RouteTable"),
                            VpcPeeringConnectionId: template.ref(peering_connection_id)
                          }

        template.output "PeeringConnectionVPC#{peer_name.camelize}",
                        template.ref(peering_connection_id),
                        description: "Peering connection ID for #{peer_name} VPC"

        OpenStruct.new(id: peer_config.fetch('vpc_id'),
                       name: peer_name,
                       cidr: peer_config.fetch('cidr'),
                       peering_connection_id: template.ref(peering_connection_id))
      end

      def list(stack_name, outputs: Aws::CloudFormation::Stack.new(stack_name).outputs)
        outputs.inject({}) do |acc, output|
          if vpc = output.output_key[OUTPUT_REGEX, 1]
            acc[vpc] = output.output_value
          end
          acc
        end
      end
    end
  end
end
