shared_examples "Backend Kinesis in environment" do  |stack_name:, environment:,
                                                       name:, shard_count:|

  camelized_stack_name = stack_name.camelize
  camelized_environment = environment.camelize
  camelized_name = name.camelize

  describe "Backend Kinesis #{name} cluster on #{environment}" do
    let(:resource_prefix) { "Kinesis#{camelized_environment}#{camelized_name}"}

    it 'Stream' do
      expect_resource template, resource_prefix + "Stream",
                     of_type: "AWS::Kinesis::Stream" do |properties|
        expect(properties[:ShardCount]).to eq(shard_count)
      end
    end
  end
end