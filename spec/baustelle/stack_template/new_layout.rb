shared_examples "New template layout" do
  context 'New template layout' do
    it 'Creates a stack resource' do
      expect_resource template, "FooNewLayout",
                      of_type: 'AWS::CloudFormation::Stack' do |properties, resource|
        expect(properties[:TemplateURL]).to eq('https://s3.amazonaws.com/bucket/FooNewLayout.json')
        parameters = properties[:Parameters]
        tags = properties[:Tags]
        expect(parameters[:VPC]).to eq(ref('foo'))
        expect(parameters[:Subnets]).to eq({"Fn::Join"=>[",", [{"Ref"=>"fooSubnetA"}, {"Ref"=>"fooSubnetB"}]]})
        expect(tags).to contain_exactly(
                          {Key: 'application', Value: 'new_layout'},
                          {Key: 'stack', Value: 'foo'},
                          {Key: 'canonical-name', Value: 'FooNewLayout'}
                        )
      end
    end
    it 'Raise error if the setting is overwritten in an environment' do
      error_config = Marshal.load(Marshal.dump(config))
      error_config.
        fetch('environments', nil).
        fetch('production', nil).
        fetch('applications', {}).
        fetch('new_layout', {})['template_layout'] = 'old'
      expect {Baustelle::StackTemplate.new(error_config).build("foo", region, "bucket")}.to raise_error(RuntimeError)
    end
    it '' do

    end
  end
end
