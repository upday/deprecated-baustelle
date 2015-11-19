shared_examples "Application in environment" do |stack_name:, camelized_stack_name:,
                                                 environment:, camelized_environment:,
                                                 app_name:, camelized_app_name:,
                                                 instance_type:, min_size:, max_size:,
                                                 solution_stack_name: nil,
                                                 availability_zones:,
                                                 config: {},
                                                 elb_public: true|

  context "Application #{app_name} in #{environment} environment" do
    it "ElasticBeanstalk Application" do
      expect_resource template, camelized_stack_name + camelized_app_name,
                      of_type: 'AWS::ElasticBeanstalk::Application' do |properties|
        expect(properties[:ApplicationName]).to eq(camelized_stack_name + camelized_app_name)
      end
    end

    it "ElasticBeanstalk Environment" do
      expect_resource template, camelized_app_name + "Env" + camelized_environment,
                      of_type: "AWS::ElasticBeanstalk::Environment" do |properties|
        expect(properties[:ApplicationName]).to eq(ref(camelized_stack_name + camelized_app_name))
        expect(properties[:EnvironmentName]).to match(/^#{environment}-[0-9a-f]+$/)
        expect(properties[:SolutionStackName]).to eq(solution_stack_name)
        option_settings = group_option_settings(properties[:OptionSettings])

        expect(option_settings["aws:autoscaling:launchconfiguration"]["InstanceType"]).
          to eq(instance_type)
        expect(option_settings["aws:autoscaling:launchconfiguration"]["IamInstanceProfile"]).
          to eq(ref('IAMInstanceProfile'))
        expect(option_settings["aws:autoscaling:asg"]["MinSize"].to_i).
          to eq(min_size)
        expect(option_settings["aws:autoscaling:asg"]["MaxSize"].to_i).
          to eq(max_size)
        expect(option_settings["aws:ec2:vpc"]["Subnets"]).
          to eq({'Fn::Join' => [',', availability_zones.map { |az|
                                  ref("#{stack_name}Subnet#{az.upcase}")
                                }]})

        expect(option_settings['aws:elasticbeanstalk:application']['Application Healthcheck URL']).
          to eq('/health')

        expect(option_settings['aws:ec2:vpc']['ELBScheme']).
          to eq(elb_public ? 'external' : 'internal')

        config.each do |key, value|
          expect(option_settings['aws:elasticbeanstalk:application:environment'][key]).
            to eq(value)
        end

        expect(option_settings['aws:elasticbeanstalk:command']).
          to eq({
                  'BatchSize' => '1',
                  'BatchSizeType' => 'Fixed'
                })

        expect(properties[:Tags]).to eq([
          { 'Key' => 'FQN',         'Value' => "#{app_name}.#{environment}.#{stack_name}" },
          { 'Key' => 'Application', 'Value' => app_name },
          { 'Key' => 'Stack',       'Value' => stack_name },
          { 'Key' => 'Environment', 'Value' => environment },
        ])
      end
    end
  end
end
