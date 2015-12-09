module Baustelle
  module CloudFormation
    module Route53
      extend self

      def apply(template, app_resource_name:, hosted_zone_name:, dns_name:, ttl:)
        template.resource(app_resource_name + 'DnsRecord', {
          Type: "AWS::Route53::RecordSet",
          Properties: {
            HostedZoneName: hosted_zone_name,
            Name: dns_name,
            Type: 'CNAME',
            ResourceRecords: [{ 'Fn::GetAtt' => [ app_resource_name, 'EndpointURL' ] }],
            TTL: ttl
          }
        })
      end
    end
  end
end
