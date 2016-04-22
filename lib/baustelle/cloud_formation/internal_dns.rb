module Baustelle
  module CloudFormation
    module InternalDNS
      extend self

      def zone(template, stack_name:, vpcs:,
               root_domain:, type: 'Internal')

        template.resource resource_name = "#{type}DNSZone",
                          Type: "AWS::Route53::HostedZone",
                          Properties: {
                            HostedZoneConfig: {
                              Comment: {
                                'Fn::Join' => ['',[
                                                 type, ' zone for ',
                                                 stack_name, ' in ',
                                                 {Ref: 'AWS::Region'}
                                               ]]
                              }
                            },
                            Name: root_domain,
                            VPCs: vpcs.map { |vpc|
                              { VPCId: vpc.id,
                                VPCRegion: template.ref('AWS::Region') }
                            }
                          }

        OpenStruct.new(id: resource_name, domain: root_domain)
      end

      private

      def cname_to_resource_name(cname)
        cname.gsub(/[^A-z0-9]/, '_')
      end
    end
  end
end
