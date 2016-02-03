module Baustelle
  module CloudFormation
    module InternalDNS
      extend self

      def zone(template, stack_name:, vpc:, peer_vpcs:)
        domain = template.join('.', stack_name, template.ref('AWS::Region'),
                               'baustelle')

        template.resource "InternalDNSZone",
                          Type: "AWS::Route53::HostedZone",
                          Properties: {
                            Name: domain,
                            VPCs: ([vpc] + peer_vpcs).
                              map { |vpc| {VPCId: vpc.id,
                                           VPCRegion: template.ref('AWS::Region')} }
                          }

        domain
      end
    end
  end
end
