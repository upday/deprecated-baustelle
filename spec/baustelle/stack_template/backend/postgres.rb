shared_examples "Backend Postgres in environment" do  |stack_name:, environment:, name:,
                                                    availability_zones:,
                                                    instance_type:, storage:|


  camelized_name = name.camelize
  camelized_environment = environment.camelize

  describe "Backend Postgres #{name} cluster on #{environment}" do
    let(:resource_prefix) { "Postgres#{camelized_environment}#{camelized_name}"}

    it 'db instance' do
      expect_resource template, resource_prefix + "DBInstance",
                     of_type: "AWS::RDS::DBInstance" do |properties|
      end
    end

    it 'db subnet group' do
      expect_resource template, resource_prefix + "SubnetGroup",
                     of_type: 'AWS::RDS::DBSubnetGroup' do |properties|
        expect(properties[:SubnetIds]).
          to eq(availability_zones.
                 map { |az| ref("#{stack_name}Subnet#{az.upcase}")})
      end
    end
  end
end
