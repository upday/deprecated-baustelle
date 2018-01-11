shared_examples "Backend Redis in environment" do  |stack_name:, camelized_stack_name:,
                                                    environment:, camelized_environment:,
                                                    name:, camelized_name:,
                                                    availability_zones:,
                                                    instance_type:, cluster_size:|

  describe "Backend Redis #{name} cluster on #{environment}" do
    let(:resource_prefix) { "Redis#{camelized_environment}#{camelized_name}"}

    it 'replication group' do
      expect_resource template, resource_prefix + "ReplicationGroup",
                     of_type: "AWS::ElastiCache::ReplicationGroup" do |properties|
        expect(properties[:AutomaticFailoverEnabled]).to eq(cluster_size < 2 ? false : true)
        expect(properties[:AutoMinorVersionUpgrade]).to eq(true)
        expect(properties[:CacheNodeType]).to eq(instance_type)
        expect(properties[:CacheSubnetGroupName]).to eq(ref(resource_prefix + "SubnetGroup"))
        expect(properties[:Engine]).to eq('redis')
        expect(properties[:EngineVersion]).to eq('3.2.10')
        expect(properties[:NumCacheClusters]).to eq(cluster_size)
        expect(properties[:SecurityGroupIds]).to eq([ref("GlobalSecurityGroup")])
      end
    end

    it 'cache subnet group' do
      expect_resource template, resource_prefix + "SubnetGroup",
                     of_type: 'AWS::ElastiCache::SubnetGroup' do |properties|
        expect(properties[:SubnetIds]).
          to eq(availability_zones.
                 map { |az| ref("#{stack_name}Subnet#{az.upcase}")})
      end
    end
  end
end
