module Baustelle
  module CloudFormation
    module PeerVPC
      extend self

      def apply(template, vpc, peer_name, peer_config)
        peering_connection_id = "PeerVPC#{template.camelize(peer_name)}PeeringConnection"
        template.resource peering_connection_id,
                          Type: "AWS::EC2::VPCPeeringConnection",
                          Properties: {
                            VpcId: vpc.id,
                            PeerVpcId: peer_config.fetch('vpc_id'),
                            Tags: [
                              {Key: 'Name', Value: "#{vpc.name}-to-#{peer_name}"}
                            ]
                          }

        template.resource "PeerVPC#{template.camelize(peer_name)}Route",
                          Type: 'AWS::EC2::Route',
                          Properties: {
                            DestinationCidrBlock: peer_config.fetch('cidr'),
                            RouteTableId: template.ref("#{vpc.name}RouteTable"),
                            VpcPeeringConnectionId: template.ref(peering_connection_id)
                          }

        template.output "PeeringConnectionVPC#{template.camelize(peer_name)}",
                        template.ref(peering_connection_id),
                        description: "Peering connection ID for #{peer_name} VPC"
      end
    end
  end
end
