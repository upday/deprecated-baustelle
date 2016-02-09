shared_examples "Application in environment" do |stack_name:, environment:, app_name:,
                                                 instance_type:, min_size:, max_size:,
                                                 solution_stack_name: nil,
                                                 availability_zones:,
                                                 config: {},
                                                 elb_public: true|

  camelized_stack_name = stack_name.camelize
  camelized_environment = environment.camelize
  camelized_app_name = app_name.camelize

  context "Application #{app_name} in #{environment} environment" do
    it 'IAM Role' do
      expect_resource template, "IAMRole",
                               of_type: 'AWS::IAM::Role'
    end

    it 'Instance profile' do
      expect_resource template, "IAMInstanceProfile",
                               of_type: 'AWS::IAM::InstanceProfile' do |properties|

        expect(properties[:Roles]).to eq([ref("IAMRole")])
      end
    end

    it "ElasticBeanstalk Application" do
      expect_resource template, camelized_stack_name + camelized_app_name,
                      of_type: 'AWS::ElasticBeanstalk::Application' do |properties|
        expect(properties[:ApplicationName]).to eq(camelized_stack_name + camelized_app_name)
      end
    end

    it "CNAME" do
      expect_cname template, [app_name.gsub('_', '-'),
                              environment.gsub('_', '-'),
                              'app.baustelle.internal'].join('.'),
                   {'Fn::GetAtt' => [camelized_app_name + "Env" + camelized_environment,
                                    'EndpointURL']}

      expect_cname template, /^#{app_name.gsub('_', '-')}.#{environment.gsub('_', '-')}.app.foo.[\w-]+.baustelle.internal$/,
                   {'Fn::GetAtt' => [camelized_app_name + "Env" + camelized_environment,
                                    'EndpointURL']}
    end

    it "ElasticBeanstalk Environment" do
      expect_resource template, camelized_app_name + "Env" + camelized_environment,
                      of_type: "AWS::ElasticBeanstalk::Environment" do |properties|
        expect(properties[:ApplicationName]).to eq(ref(camelized_stack_name + camelized_app_name))
        expect(properties[:EnvironmentName]).to match(/^#{environment}-[0-9a-f]+$/)
        expect(properties[:SolutionStackName]).to eq(solution_stack_name)
        expect(properties[:CNAMEPrefix]).
          to eq({'Fn::Join' => ['-', [stack_name, ref('AWS::Region'),
                                      "#{environment}-#{app_name}".gsub('_', '-')]]})
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
                  'BatchSize' => '50',
                  'BatchSizeType' => 'Percentage'
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
