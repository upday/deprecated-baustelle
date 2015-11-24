shared_examples "Backend Redis in environment" do  |stack_name:, camelized_stack_name:,
                                                    environment:, camelized_environment:,
                                                    name:, camelized_name:,
                                                    availability_zones:,
                                                    instance_type:, cluster_size:|

  describe "Backend Redis #{name} cluster on #{environment}" do
    let(:resource_prefix) { "Redis#{camelized_environment}#{camelized_name}"}

    it 'replication group' do
      expect_resoure template, resource_prefix + "ReplicationGroup",
                     of_type: "AWS::ElastiCache::ReplicationGroup" do |properties|
        expect(properties[:AutomaticFailoverEnabled]).to eq(cluster_size < 2 ? false : true)
        expect(properties[:AutoMinorVersionUpgrade]).to be_true
        expect(properties[:CacheNodeType]).to eq(instance_type)
        expect(properties[:Engine]).to eq('redis')
        expect(properties[:EngineVersion]).to eq('2.8.19')
        expect(properties[:NumCacheClusters]).to eq(cluster_size)
        expect(properties[:SecurityGroupIds]).to eq([template.ref("GlobalSecurityGroup")])
      end
    end
  end
end
