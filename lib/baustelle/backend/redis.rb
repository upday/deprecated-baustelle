module Baustelle
  module Backend
    class Redis
      def initialize(name, options, vpc:)
        @name = name
        @options = options
        @vpc = vpc
      end

      def build(template)
        template.resource sg = "#{prefix}SubnetGroup",
                          Type: 'AWS::ElastiCache::SubnetGroup',
                          Properties: {
                            Description: 'SubnetGroup',
                            SubnetIds: @vpc.subnets.map(&:id)
                          }

        template.resource "#{prefix}ReplicationGroup",
                          Type: 'AWS::ElastiCache::ReplicationGroup',
                          Properties: {
                            ReplicationGroupDescription: @name,
                            AutomaticFailoverEnabled: @options.fetch('cluster_size') > 1,
                            AutoMinorVersionUpgrade: true,
                            CacheNodeType: 'cache.m1.medium',
                            CacheSubnetGroupName: template.ref(sg),
                            Engine: 'redis',
                            EngineVersion: '2.8.19',
                            NumCacheClusters: @options.fetch('cluster_size'),
                            SecurityGroupIds: [template.ref('GlobalSecurityGroup')]
                          }

      end

      def output(template)
         host = {'Fn::GetAtt' => ["#{prefix}ReplicationGroup", 'PrimaryEndPoint.Address']}
         port = {'Fn::GetAtt' => ["#{prefix}ReplicationGroup", 'PrimaryEndPoint.Port']}

        {
          'url' => {'Fn::Join' => ['', ['redis://', host, ':', port]] },
          'host' => host,
          'port' => port
        }
      end

      private

      def prefix
        "Redis#{@name.camelize}"
      end
    end
  end
end
