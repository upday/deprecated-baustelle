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


      def cname(template, zone, name:, target:, ttl: 60)
        name = Array(name).map(&:underscore).
               map { |s| s.gsub('_', '-') }.
               join('.')
        resource_name = ['InternalDNSZone', name].flatten.
                        map(&:camelize).join
        template.resource resource_name,
                          Type: 'AWS::Route53::RecordSet',
                          Properties: {
                            HostedZoneId: zone.id,
                            Type: 'CNAME',
                            TTL: ttl,
                            ResourceNameRecords: [target],
                            Name: domain = "#{name}.#{zone.domain}"
                          }
        domain
      end

  end
end
