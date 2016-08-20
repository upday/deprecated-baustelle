require 'spec_helper'
require_relative 'stack_template/vpc'
require_relative 'stack_template/application'
require_relative 'stack_template/backend/rabbitmq'
require_relative 'stack_template/backend/redis'
require_relative 'stack_template/backend/postgres'
require_relative 'stack_template/backend/kinesis'
require_relative 'stack_template/peer_vpc'

describe Baustelle::StackTemplate do
  let(:stack_template) { Baustelle::StackTemplate.new(config) }

  let(:config) {
    YAML.load(<<-YAML)
---
https: &https
  https: true
  ssl_certificate: arn:aws:iam::123456789012:server-certificate/baustelle_com
  ssl_reference_policy: ELBSecurityPolicy-2015-05

stacks:
  ruby:
    solution: Ruby AWS EB Solution
  ruby2.2-with-datadog:
    solution: Ruby AWS EB Solution
    ami:
      us-east-1: ami-123456
  ruby2.2-new-name:
    solution: Ruby AWS EB Solution V2.0
    ami:
      us-east-1: ami-654321

bastion:
  instance_type: t2.micro
  ami:
    us-east-1: ami-123456
  github_ssh_keys:
    - github_user
  dns_zone: example.com

vpc:
  cidr: 172.31.0.0/16
  subnets:
    a: 172.31.0.0/20
    b: 172.31.16.0/20
  peers:
    staging:
      vpc_id: vpc-123456
      cidr: 172.30.0.0/16

backends:
  RabbitMQ:
    main:
      ami:
        us-east-1: ami-123456
      instance_type: m4.large
      cluster_size: 4
  Redis:
    main:
      cache_node_type: cache.r3.large
      cluster_size: 2
  Kinesis:
    main:
      shard_count: 2
  Postgres:
    unimportant_data:
      instance_type: db.m4.large
      storage: 10
      username: foo
      password: qwerty
  External:
    postgres:
      url: postgres://production

applications:
  custom_hello_world:
    stack: ruby2.2-with-datadog
    instance_type: t2.small
    scale:
      min: 1
      max: 1
    elb:
      visibility: internal
  hello_world:
    stack: ruby
    instance_type: t2.small
    scale:
      min: 2
      max: 4
    config:
      RAILS_ENV: production
      RABBITMQ_URL: backend(RabbitMQ:main:url)
      DATABASE_URL: backend(External:postgres:url)
      CUSTOM_HELLO_URL: application(custom_hello_world:url)
      HTTPS_APP_URL: application(https_hello_world:url)
      OLD_HOSTNAME_SCHEME_APP: application(hello_world_old_hostname_scheme:url)
  https_hello_world:
    stack: ruby2.2-with-datadog
    instance_type: t2.small
    scale:
      min: 1
      max: 1
    elb:
      <<: *https
    dns:
      hosted_zone: example.com
      name: app.example.com
  hello_world_old_hostname_scheme:
    stack: ruby2.2-with-datadog
    instance_type: t2.small
    hostname_scheme: old
    scale:
      min: 1
      max: 1
  application_not_in_loadtest:
    stack: ruby
    instance_type: t2.small
    scale:
      min: 1
      max: 1
  application_only_staging:
    disabled: true
    stack: ruby
    instance_type: t2.small
    scale:
      min: 1
      max: 1
  application_with_dns_in_production:
    stack: ruby
    instance_type: t1.small
    scale:
      min: 1
      max: 1
  application_with_specific_autoscaling_rules:
    stack: ruby
    instance_type: t1.small
    scale:
      min: 1
      max: 2
    trigger:
      measure_name: CPUUtilization
      lower_threshold: 2000000
      upper_threshold: 6000000
  application_with_even_more_specific_autoscaling_rules:
    stack: ruby
    instance_type: t1.small
    scale:
      min: 1
      max: 3
    trigger:
      measure_name: Latency
      breach_duration: 2
      period: 2
      lower_threshold: 1
      upper_threshold: 2
      unit: Seconds
      upper_breach_scale_increment: 2
  application_without_specific_autoscaling_rules:
    stack: ruby
    instance_type: t1.small
    scale:
      min: 1
      max: 2
  application_default_environment_naming:
    stack: ruby
    instance_type: t1.small
    scale:
      min: 1
      max: 2
  application_default_environment_naming_override:
    stack: ruby
    instance_type: t1.small
    scale:
      min: 1
      max: 2
  application_new_environment_naming:
    stack: ruby
    instance_type: t1.small
    scale:
      min: 1
      max: 2
    new_environment_naming: true


environments:
  production:
    applications:
      application_with_dns_in_production:
        dns:
          hosted_zone: baustelle.org
          name: myapp.baustelle.org
      application_compat_environment_naming:
        new_environment_naming: false
  staging:
    backends:
      RabbitMQ:
        main:
          cluster_size: 1
      Redis:
        main:
          cluster_size: 1
      Kinesis:
        main:
          shard_count: 1
      External:
        postgres:
          url: postgres://staging
    applications:
      hello_world:
        instance_type: t2.micro
        scale:
          min: 1
          max: 1
        config:
          RAILS_ENV: staging
      application_only_staging:
        disabled: false
  loadtest:
    applications:
      application_not_in_loadtest:
        disabled: yes
  naming:
    applications:
      application_default_environment_naming_override:
        new_environment_naming: true
      application_compat_environment_naming:
        new_environment_naming: true
      application_default_environment_naming:
        stack: ruby2.2-new-name
      application_new_environment_naming:
        stack: ruby2.2-new-name
    YAML
  }

  def expect_resource(template, resource_name, of_type: nil)
    resource = template[:Resources][resource_name]
    expect(resource).not_to be_nil,
                            "expected #{resource_name} to be present. Available resource names #{template[:Resources].keys}"
    expect(resource[:Type]).to eq(of_type) if of_type
    yield resource[:Properties], resource if block_given?
  end

  def ref(name)
    {'Ref' => name}
  end

  def group_option_settings(option_settings)
    initial_acc = {}
    option_settings.inject(initial_acc) do |acc, entry|
      acc[entry[:Namespace]] ||= {}
      acc[entry[:Namespace]][entry[:OptionName]] = entry[:Value]
      acc
    end
  end

  describe '#build' do
    let(:region) { 'us-east-1' }
    subject { stack_template.build("foo", region) }

    context "returns template" do
      let(:template) { (subject.as_json) }

      specify "all resource names are alphanumeric" do
        expect(template[:Resources].keys).
          to all(match(/^[A-z0-9]+$/))
      end

      include_examples "VPC resource declaration"

      include_examples "Peer VPC", name: 'staging',
                       vpc_id: 'vpc-123456',
                       cidr: '172.30.0.0/16'

      include_examples "Application in environment",
                       stack_name: 'foo',
                       environment: 'production',
                       app_name: "hello_world",
                       instance_type: "t2.small",
                       min_size: 2, max_size: 4,
                       solution_stack_name: 'Ruby AWS EB Solution',
                       availability_zones: %w(a b),
                       config: {'RAILS_ENV' => 'production'}

      include_examples "Application in environment",
                       stack_name: 'foo',
                       environment: 'staging',
                       app_name: "hello_world",
                       instance_type: "t2.micro",
                       min_size: 1, max_size: 1,
                       solution_stack_name: 'Ruby AWS EB Solution',
                       availability_zones: %w(a b),
                       config: {'RAILS_ENV' => 'staging'}

      include_examples "Application in environment",
                       stack_name: 'foo',
                       environment: 'staging',
                       app_name: "custom_hello_world",
                       instance_type: "t2.small",
                       min_size: 1, max_size: 1,
                       solution_stack_name: 'Ruby AWS EB Solution',
                       availability_zones: %w(a b),
                       elb_public: false

      include_examples "Application in environment",
                       stack_name: 'foo',
                       environment: 'production',
                       app_name: "custom_hello_world",
                       instance_type: "t2.small",
                       min_size: 1, max_size: 1,
                       solution_stack_name: 'Ruby AWS EB Solution',
                       availability_zones: %w(a b),
                       elb_public: false


      include_examples "Backend RabbitMQ in environment",
                       stack_name: 'foo',
                       environment: 'production',
                       name: "main",
                       availability_zones: %w(a b),
                       instance_type: 'm4.large',
                       cluster_size: 4

      include_examples "Backend RabbitMQ in environment",
                       stack_name: 'foo',
                       environment: 'staging',
                       name: "main",
                       availability_zones: %w(a b),
                       instance_type: 'm4.large',
                       cluster_size: 1

      include_examples "Backend Redis in environment",
                       stack_name: 'foo',
                       camelized_stack_name: "Foo",
                       environment: 'production',
                       camelized_environment: 'Production',
                       name: "main",
                       camelized_name: "Main",
                       availability_zones: %w(a b),
                       instance_type: 'cache.r3.large',
                       cluster_size: 2

      include_examples "Backend Redis in environment",
                       stack_name: 'foo',
                       camelized_stack_name: "Foo",
                       environment: 'staging',
                       camelized_environment: 'Staging',
                       name: "main",
                       camelized_name: "Main",
                       availability_zones: %w(a b),
                       instance_type: 'cache.r3.large',
                       cluster_size: 1

      include_examples "Backend Postgres in environment",
                       stack_name: 'foo',
                       environment: 'staging',
                       name: "unimportant_data",
                       availability_zones: %w(a b),
                       instance_type: 'db.m4.large',
                       storage: 10

      include_examples "Backend Postgres in environment",
                       stack_name: 'foo',
                       environment: 'staging',
                       name: "unimportant_data",
                       availability_zones: %w(a b),
                       instance_type: 'db.m4.large',
                       storage: 10

      include_examples "Backend Kinesis in environment",
                       stack_name: 'foo',
                       environment: 'production',
                       name: "main",
                       shard_count: 2

      include_examples "Backend Kinesis in environment",
                       stack_name: 'foo',
                       environment: 'staging',
                       name: "main",
                       shard_count: 1

      it 'creates security group for the platform' do
        expect_resource template, "GlobalSecurityGroup",
                        of_type: 'AWS::EC2::SecurityGroup'
      end

      it 'creates IAM role for the platform instances' do
        expect_resource template, 'IAMRole',
                        of_type: 'AWS::IAM::Role'
      end

      it 'creates instance profile for instances' do
        expect_resource template, 'IAMInstanceProfile',
                        of_type: 'AWS::IAM::InstanceProfile' do |properties|
          expect(properties[:Roles]).to include(ref('IAMRole'))
        end
      end

      it 'creates no ssl configuration when https is not enabled' do
        expect_resource template, 'HelloWorldEnvProduction' do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])

          elb_listeners = option_settings.select { |key,_| key.start_with?('aws:elb:listener:') }
          expect(elb_listeners).
            to eq('aws:elb:listener:80' => {
                    'ListenerEnabled' => 'true'
                  },
                  'aws:elb:listener:443' => {
                    'ListenerEnabled' => 'false'
                  }
                 )

          expect(option_settings['aws:elb:policies:SSL']).to be_nil
        end
      end

      it 'creates ssl configuration when https is enabled' do
        expect_resource template, 'HttpsHelloWorldEnvProduction' do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])

          elb_listeners = option_settings.select { |key,_| key.start_with?('aws:elb:listener:') }
          expect(elb_listeners.length).to eq(2)

          expect(elb_listeners['aws:elb:listener:80']).to eq({
                                                               'ListenerEnabled' => 'false',
                                                             })

          expect(elb_listeners['aws:elb:listener:443']).to eq({
                                                                'ListenerEnabled' => 'true',
                                                                'ListenerProtocol' => 'HTTPS',
                                                                'InstanceProtocol' => 'HTTP',
                                                                'InstancePort' => '80',
                                                                'SSLCertificateId' => 'arn:aws:iam::123456789012:server-certificate/baustelle_com',
                                                                'PolicyNames' => 'SSL'
                                                              })

          expect(option_settings['aws:elb:policies:SSL']).to eq({
                                                                  'SSLReferencePolicy' => 'ELBSecurityPolicy-2015-05',
                                                                })
        end
      end

      context "internal DNS" do
        it 'creates internal DNS Zone' do
          expect_resource template,"InternalDNSZone",
                          of_type: "AWS::Route53::HostedZone" do |properties|
            expect(properties[:Name]).to eq('baustelle.internal')
            expect(properties[:VPCs]).to include({VPCId: {'Ref' => 'foo'},
                                                  VPCRegion: {'Ref' => 'AWS::Region'}})

          end
        end

        it 'creates peering DNS Zone' do
          expect_resource template,"PeeringDNSZone",
                          of_type: "AWS::Route53::HostedZone" do |properties|
            expect(properties[:Name]).to eq("foo.#{region}.baustelle.internal")
            expect(properties[:VPCs]).not_to include({VPCId: {'Ref' => 'foo'},
                                                      VPCRegion: {'Ref' => 'AWS::Region'}})
            expect(properties[:VPCs]).to include({VPCId: 'vpc-123456',
                                                  VPCRegion: {'Ref' => 'AWS::Region'}})
          end
        end
      end

      it 'links RabbitMQ server to the app' do
        expect_resource template, "HelloWorldEnvProduction" do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])
          app_env = option_settings["aws:elasticbeanstalk:application:environment"]
          expect(app_env["RABBITMQ_URL"]).
            to eq({'Fn::Join' =>
                   ['', [
                      'amqp://yana:_yana101_@',
                      {'Fn::GetAtt' => ["RabbitMQProductionMainELB", 'DNSName']},
                      ':5672'
                    ]
                   ]
                  })
        end
      end

      it 'links External backend to the app' do
        expect_resource template, "HelloWorldEnvProduction" do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])
          app_env = option_settings["aws:elasticbeanstalk:application:environment"]
          expect(app_env["DATABASE_URL"]).to eq("postgres://production")
        end

        expect_resource template, "HelloWorldEnvStaging" do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])
          app_env = option_settings["aws:elasticbeanstalk:application:environment"]
          expect(app_env["DATABASE_URL"]).to eq("postgres://staging")
        end
      end

      it 'links application within the same environment' do
        expect_resource template, "HelloWorldEnvProduction" do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])
          app_env = option_settings["aws:elasticbeanstalk:application:environment"]
          expect(app_env["CUSTOM_HELLO_URL"]).
            to eq({'Fn::Join' =>
                   ['', ['http://', 'foo-us-east-1-production-custom-hello-world.us-east-1.elasticbeanstalk.com']]
                  })
        end
      end

      it 'links application using the old elasticbeanstalk url scheme' do
        expect_resource template, "HelloWorldEnvProduction" do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])
          app_env = option_settings["aws:elasticbeanstalk:application:environment"]
          expect(app_env["OLD_HOSTNAME_SCHEME_APP"]).
            to eq({'Fn::Join' =>
                   ['', ['http://', 'foo-us-east-1-production-hello-world-old-hostname-scheme.elasticbeanstalk.com']]
                  })
        end
      end

      it 'links HTTPS application within the same environment' do
        expect_resource template, "HelloWorldEnvProduction" do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])
          app_env = option_settings["aws:elasticbeanstalk:application:environment"]
          expect(app_env["HTTPS_APP_URL"]).
            to eq({'Fn::Join' => ['', ['https://', 'app.example.com']]})
        end
      end

      it 'uses custom AMI for customized stack' do
        expect_resource template, "CustomHelloWorldEnvProduction" do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])

          expect(option_settings["aws:autoscaling:launchconfiguration"]["ImageId"]).
            to eq({'Fn::FindInMap' => [ 'StackAMIs', {'Ref' => 'AWS::Region'},
                                        'Ruby22WithDatadog']})
          expect(template[:Mappings]['StackAMIs']['us-east-1']['Ruby22WithDatadog']).
            to eq('ami-123456')
        end
      end

      it 'includes non-disabled applications' do
        expect_resource template, 'ApplicationNotInLoadtestEnvProduction'
        expect_resource template, 'ApplicationNotInLoadtestEnvStaging'
      end

      it 'does not include disabled applications' do
        expect(template[:Resources]['ApplicationNotInLoadtestEnvLoadtest']).to be_nil
      end

      it 'allows to override disabled flag with false' do
        expect_resource template, 'ApplicationOnlyStagingEnvStaging'
        expect(template[:Resources]['ApplicationOnlyStagingEnvProd']).to be_nil
        expect(template[:Resources]['ApplicationOnlyStagingEnvLoadTest']).to be_nil
      end

      context 'generates bastion host configuration' do
        it 'security group' do
          expect_resource template, "BastionSecurityGroup",
                          of_type: 'AWS::EC2::SecurityGroup'
        end

        it 'launch configuration' do
          expect_resource template, "BastionLaunchConfiguration",
                          of_type: 'AWS::AutoScaling::LaunchConfiguration' do |properties|
            expect(properties[:AssociatePublicIpAddress]).to eq(true)
            expect(properties[:InstanceType]).to eq('t2.micro')
            expect(properties[:IamInstanceProfile]).to eq(ref('IAMInstanceProfileBastionHost'))
            expect(properties[:ImageId]).
              to eq({'Fn::FindInMap' => ["BastionAMIs", ref('AWS::Region'),
                                         "Global"]})
            expect(properties[:SecurityGroups]).to eq([ref('GlobalSecurityGroup'),
                                                       ref('BastionSecurityGroup')])

            # TODO: improve this test
            expect(properties[:UserData].keys.first).
              to eq('Fn::Base64')
          end
        end

        it 'autoscaling group' do
          availability_zones = %w(a b)

          expect_resource template, "BastionASG",
                          of_type: 'AWS::AutoScaling::AutoScalingGroup' do |properties, res|
            expect(properties[:AvailabilityZones]).
              to eq(availability_zones.map { |az|
                      {'Fn::Join' => ['', [ref('AWS::Region'), az]]}
                    })

            expect(properties[:MinSize]).to eq(1)
            expect(properties[:MaxSize]).to eq(1)
            expect(properties[:DesiredCapacity]).to eq(1)
            expect(properties[:LaunchConfigurationName]).to eq(ref('BastionLaunchConfiguration'))
            expect(res[:UpdatePolicy]).to eq({AutoScalingRollingUpdate: {MaxBatchSize: 1}})
          end
        end
      end

      context 'Autoscaling trigger' do
        it 'updates the trigger for AutoScaling the environment' do
          expect_resource template, "ApplicationWithSpecificAutoscalingRulesEnvStaging" do |properties|
            trigger_options = properties[:OptionSettings].select { |options| options[:Namespace] == 'aws:autoscaling:trigger' }
            measure_name = (trigger_options.select{|options| options[:OptionName] == 'MeasureName'})
            expect(measure_name.length).to eq(1)
            expect(measure_name[0][:Value]).to eq('CPUUtilization')
            lower_threshold = (trigger_options.select{|options| options[:OptionName] == 'LowerThreshold'})
            expect(lower_threshold.length).to eq(1)
            expect(lower_threshold[0][:Value]).to eq("2000000")
            upper_threshold = (trigger_options.select{|options| options[:OptionName] == 'UpperThreshold'})
            expect(upper_threshold.length).to eq(1)
            expect(upper_threshold[0][:Value]).to eq("6000000")
          end
        end

        it 'updates the autoscaling thresholds with very specific rules' do
          expect_resource template, "ApplicationWithEvenMoreSpecificAutoscalingRulesEnvStaging" do |properties|
            trigger_options = properties[:OptionSettings].select { |options| options[:Namespace] == 'aws:autoscaling:trigger' }
            measure_name = (trigger_options.select{|options| options[:OptionName] == 'MeasureName'})
            expect(measure_name.length).to eq(1)
            expect(measure_name[0][:Value]).to eq('Latency')
            breach_duration = (trigger_options.select{|options| options[:OptionName] == 'BreachDuration'})
            expect(breach_duration.length).to eq (1)
            expect(breach_duration[0][:Value]).to eq("2")
            breach_duration = (trigger_options.select{|options| options[:OptionName] == 'Period'})
            expect(breach_duration.length).to eq (1)
            expect(breach_duration[0][:Value]).to eq("2")
            lower_threshold = (trigger_options.select{|options| options[:OptionName] == 'LowerThreshold'})
            expect(lower_threshold.length).to eq(1)
            expect(lower_threshold[0][:Value]).to eq("1")
            upper_threshold = (trigger_options.select{|options| options[:OptionName] == 'UpperThreshold'})
            expect(upper_threshold.length).to eq(1)
            expect(upper_threshold[0][:Value]).to eq("2")
            unit = (trigger_options.select{|options| options[:OptionName] == 'Unit'})
            expect(unit.length).to eq(1)
            expect(unit[0][:Value]).to eq('Seconds')
            upper_breach_scale_increment = (trigger_options.select{|options| options[:OptionName] == 'UpperBreachScaleIncrement'})
            expect(upper_breach_scale_increment.length).to eq(1)
            expect(upper_threshold[0][:Value]).to eq("2")
          end
        end

        it 'does not set Trigger' do
          expect_resource template, "ApplicationWithoutSpecificAutoscalingRulesEnvStaging" do |properties|
            trigger_options = properties[:OptionSettings].select { |options| options[:Namespace] == 'aws:autoscaling:trigger' }
            expect(trigger_options.length).to eq(0)
          end
        end
      end

      context 'Environment Naming' do
        context 'default naming' do
          it 'creates the staging environment' do
            expect_resource template, "ApplicationDefaultEnvironmentNamingEnvStaging" do |properties|
              env_name = properties.fetch(:EnvironmentName)
              expect(env_name).to match(/staging-[0-9a-f]{10}/)
              expect(env_name).to eq('staging-b27bc0622a')
            end
          end
          it 'creates the production environment' do
            expect_resource template, "ApplicationDefaultEnvironmentNamingEnvProduction" do |properties|
              env_name = properties.fetch(:EnvironmentName)
              expect(env_name).to match(/production-[0-9a-f]{10}/)
              expect(env_name).to eq('production-b27bc0622a')
            end
          end
          it 'does not change environment name because of stack change' do
            expect_resource template, "ApplicationDefaultEnvironmentNamingEnvNaming" do |properties|
              env_name = properties.fetch(:EnvironmentName)
              expect(env_name).to match(/naming-[0-9a-f]{10}/)
              expect(env_name).to eq('naming-b27bc0622a')
            end
          end
        end

        context 'new naming' do
          it 'creates the staging environment' do
            expect_resource template, "ApplicationNewEnvironmentNamingEnvStaging" do |properties|
              env_name = properties.fetch(:EnvironmentName)
              expect(env_name).to match(/staging-[0-9a-f]{10}/)
              expect(env_name).to eq('staging-df07849d82')
            end
          end
          it 'creates the staging environment' do
            expect_resource template, "ApplicationNewEnvironmentNamingEnvProduction" do |properties|
              env_name = properties.fetch(:EnvironmentName)
              expect(env_name).to match(/production-[0-9a-f]{10}/)
              expect(env_name).to eq('production-df07849d82')
            end
          end
          it 'changes environment name because of stack change' do
            expect_resource template, "ApplicationNewEnvironmentNamingEnvNaming" do |properties|
              env_name = properties.fetch(:EnvironmentName)
              expect(env_name).to match(/naming-[0-9a-f]{10}/)
              expect(env_name).to eq('naming-0dc7fe324c')
            end
          end
        end

        context 'override' do
          it 'respects environment defaults' do
            expect_resource template, "ApplicationDefaultEnvironmentNamingOverrideEnvStaging" do |properties|
              env_name = properties.fetch(:EnvironmentName)
              expect(env_name).to match(/staging-[0-9a-f]{10}/)
              expect(env_name).to eq('staging-07573f5c59')
            end
            expect_resource template, "ApplicationDefaultEnvironmentNamingOverrideEnvProduction" do |properties|
              env_name = properties.fetch(:EnvironmentName)
              expect(env_name).to match(/production-[0-9a-f]{10}/)
              expect(env_name).to eq('production-07573f5c59')
            end
            expect_resource template, "ApplicationDefaultEnvironmentNamingOverrideEnvNaming" do |properties|
              env_name = properties.fetch(:EnvironmentName)
              expect(env_name).to match(/naming-[0-9a-f]{10}/)
              expect(env_name).to eq('naming-3216164a1a')
            end
          end
        end

        context 'backwards compatibility' do
          it 'does not change old names' do
            eb_env_name_backwards_compatibility = lambda do |stack_name, app_name, env_name|
              "#{env_name}-#{Digest::SHA1.hexdigest([stack_name, app_name].join)[0,10]}"
            end
            env_hash = Baustelle::CloudFormation::EBEnvironment.eb_env_name('stack','app','env')

            expect(env_hash).to eq(eb_env_name_backwards_compatibility.call('stack','app','env'))
          end
        end


      end

    end
  end
end
