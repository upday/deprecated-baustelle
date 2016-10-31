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

    it 'Creates child template' do
      expect(subject.childs).to_not be_nil
      expect(subject.childs.length).to eq(1)
      expect(subject.childs['new_layout']).to_not be_nil
    end

    context 'child template' do
      let(:region) { 'us-east-1' }
      let(:parent_template) { stack_template.build("foo", region, "bucket") }
      subject { parent_template.childs['new_layout'] }
      let(:template) { (subject.as_json) }

      it 'has Application' do
        expect_resource template, 'FooNewLayout', of_type: 'AWS::ElasticBeanstalk::Application' do |properties, resource|
          expect(properties[:ApplicationName]).to eq('FooNewLayout')
        end
      end

      it 'has additional tags for the environment' do
        expect_resource template, 'NewLayoutEnvStaging', of_type: 'AWS::ElasticBeanstalk::Environment' do |properties, resource|
          expect(properties[:Tags]).to contain_exactly(
            {'Key'=>'FQN', 'Value'=>'new_layout.staging.foo'},
            {'Key'=>'Application', 'Value'=>'new_layout'},
            {'Key'=>'Stack', 'Value'=>'foo'},
            {'Key'=>'Environment', 'Value'=>'staging'},
            {'Key'=>'application', 'Value'=>'new_layout'},
            {'Key'=>'product', 'Value'=>'upday'}
          )
        end
      end

    end
  end
end
