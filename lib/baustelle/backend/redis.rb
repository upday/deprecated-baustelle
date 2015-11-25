module Baustelle
  module Backend
    class Redis
      def initialize(name, options, vpc:)
        @name = name
        @options = options
        @vpc = vpc
      end

      def build(template)

        template.resource sg = "Redis#{template.camelize(@name)}SubnetGroup",
                          Type: 'AWS::ElastiCache::SubnetGroup',
                          Properties: {
                            Description: 'SubnetGroup',
                            SubnetIds: @vpc.subnets.map(&:id)
                          }

        template.resource rg = "Redis#{template.camelize(@name)}ReplicationGroup",
                          Type: 'AWS::ElastiCache::ReplicationGroup',
                          Properties: {
                            ReplicationGroupDescription: @name,
                            AutomaticFailoverEnabled: true,
                            AutoMinorVersionUpgrade: true,
                            CacheNodeType: 'cache.m1.medium',
                            CacheSubnetGroupName: template.ref(sg),
                            Engine: 'redis',
                            EngineVersion: '2.8.19',
                            NumCacheClusters: @options['cluster_size'],
                            SecurityGroupIds: [template.ref('GlobalSecurityGroup')]
                          }

      end

      def output(template)
         host = {'Fn::GetAtt' => ["Redis#{template.camelize(@name)}ReplicationGroup", 'PrimaryEndPoint.Address']}
         port = {'Fn::GetAtt' => ["Redis#{template.camelize(@name)}ReplicationGroup", 'PrimaryEndPoint.Port']}

        {
          'url' => {'Fn::Join' => ['', ['redis://', host, ':', port]] },
          'host' => host,
          'port' => port
        } 
      end
    end
  end
end