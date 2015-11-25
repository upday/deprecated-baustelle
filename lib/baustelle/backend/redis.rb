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
                            ReplicationGroupDescription: 'foo',
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
        @options.inject({}) do |output, (key, value)|
          output[key.to_s] = value
          output
        end
      end
    end
  end
end