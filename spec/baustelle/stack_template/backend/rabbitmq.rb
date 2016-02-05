shared_examples "Backend RabbitMQ in environment" do  |stack_name:, environment:,
                                                       name:, availability_zones:,
                                                       instance_type:, cluster_size:|

  camelized_stack_name = stack_name.camelize
  camelized_environment = environment.camelize
  camelized_name = name.camelize

  describe "Backend RabbitMQ #{name} cluster on #{environment}" do
    let(:resource_prefix) { "RabbitMQ#{camelized_environment}#{camelized_name}"}
    it 'launch configuration' do
      expect_resource template, resource_prefix + "LaunchConfiguration",
                      of_type: 'AWS::AutoScaling::LaunchConfiguration' do |properties|
        expect(properties[:AssociatePublicIpAddress]).to eq(true)
        expect(properties[:InstanceType]).to eq(instance_type)
        expect(properties[:ImageId]).
          to eq({'Fn::FindInMap' => ["BackendAMIs", ref('AWS::Region'),
                                     "RabbitMq#{camelized_environment}#{camelized_name}"]})
      end
    end

    it 'autoscaling group' do
      expect_resource template, resource_prefix + "ASG",
                      of_type: 'AWS::AutoScaling::AutoScalingGroup' do |properties|
        expect(properties[:LoadBalancerNames]).to include(ref(resource_prefix + "ELB"))
        expect(properties[:AvailabilityZones]).
          to eq(availability_zones.map { |az|
                  {'Fn::Join' => ['', [ref('AWS::Region'), az]]}
                })

        expect(properties[:MinSize]).to eq(cluster_size)
        expect(properties[:MaxSize]).to eq(cluster_size)
        expect(properties[:DesiredCapacity]).to eq(cluster_size)
      end
    end

    it 'load balancer' do
      expect_resource template, resource_prefix + "ELB",
                      of_type: 'AWS::ElasticLoadBalancing::LoadBalancer' do |properties|
        expect(properties[:CrossZone]).to eq(true)
      end
    end

    it 'internal DNS' do
      expect_cname template, "#{environment}-#{name}.rabbitmq.backend.baustelle.internal",
                   {'Fn::GetAtt' => ["RabbitMQ#{camelized_environment}#{camelized_name}ELB",
                                     'DNSName']}

      expect_cname template, /^#{environment}-#{name}.rabbitmq.backend.foo.[\w-]+.baustelle.internal$/,
                   {'Fn::GetAtt' => ["RabbitMQ#{camelized_environment}#{camelized_name}ELB",
                                     'DNSName']}
    end
  end
end
