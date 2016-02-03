module Baustelle
  module CloudFormation
    module InternalDNS
      extend self

      def zone(template, stack_name:, vpc:)
        template.resource "InternalDNSZone",
                          Type: "AWS::Route53::HostedZone",
                          Properties: {
                            HostedZoneConfig: {
                              Comment: {
                                'Fn::Join' => ['',[
                                                 stack_name, ' in ',
                                                 {Ref: 'AWS::Region'}
                                               ]]
                              }
                            },
                            Name: 'baustelle',
                            VPCs:{VPCId: vpc.id,
                                  VPCRegion: template.ref('AWS::Region') }
                          }

        OpenStruct.new(id: 'InternalDNSZone', domain: domain)
      end
    end
  end
end
