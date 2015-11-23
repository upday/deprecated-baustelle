require 'spec_helper'
require_relative 'stack_template/vpc'
require_relative 'stack_template/application'
require_relative 'stack_template/backend/rabbitmq'
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
  https_hello_world:
    stack: ruby2.2-with-datadog
    instance_type: t2.small
    scale:
      min: 1
      max: 1
    elb:
      <<: *https
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

environments:
  production: {}
  staging:
    backends:
      RabbitMQ:
        main:
          cluster_size: 1
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
    subject { stack_template.build("foo") }

    context "returns template" do
      let(:template) { (subject.as_json) }

      include_examples "VPC resource declaration"

      include_examples "Peer VPC", name: 'staging',
                       camelized_name: 'Staging',
                       vpc_id: 'vpc-123456',
                       cidr: '172.30.0.0/16'

      include_examples "Application in environment",
                       stack_name: 'foo',
                       camelized_stack_name: "Foo",
                       environment: 'production',
                       camelized_environment: 'Production',
                       app_name: "hello_world",
                       camelized_app_name: "HelloWorld",
                       instance_type: "t2.small",
                       min_size: 2, max_size: 4,
                       solution_stack_name: 'Ruby AWS EB Solution',
                       availability_zones: %w(a b),
                       config: {'RAILS_ENV' => 'production'}

      include_examples "Application in environment",
                       stack_name: 'foo',
                       camelized_stack_name: "Foo",
                       environment: 'staging',
                       camelized_environment: 'Staging',
                       app_name: "hello_world",
                       camelized_app_name: "HelloWorld",
                       instance_type: "t2.micro",
                       min_size: 1, max_size: 1,
                       solution_stack_name: 'Ruby AWS EB Solution',
                       availability_zones: %w(a b),
                       config: {'RAILS_ENV' => 'staging'}

      include_examples "Application in environment",
                       stack_name: 'foo',
                       camelized_stack_name: "Foo",
                       environment: 'staging',
                       camelized_environment: 'Staging',
                       app_name: "custom_hello_world",
                       camelized_app_name: "CustomHelloWorld",
                       instance_type: "t2.small",
                       min_size: 1, max_size: 1,
                       solution_stack_name: 'Ruby AWS EB Solution',
                       availability_zones: %w(a b),
                       elb_public: false

      include_examples "Application in environment",
                       stack_name: 'foo',
                       camelized_stack_name: "Foo",
                       environment: 'production',
                       camelized_environment: 'Production',
                       app_name: "custom_hello_world",
                       camelized_app_name: "CustomHelloWorld",
                       instance_type: "t2.small",
                       min_size: 1, max_size: 1,
                       solution_stack_name: 'Ruby AWS EB Solution',
                       availability_zones: %w(a b),
                       elb_public: false


      include_examples "Backend RabbitMQ in environment",
                       stack_name: 'foo',
                       camelized_stack_name: "Foo",
                       environment: 'production',
                       camelized_environment: 'Production',
                       name: "main",
                       camelized_name: "Main",
                       availability_zones: %w(a b),
                       instance_type: 'm4.large',
                       cluster_size: 4

      include_examples "Backend RabbitMQ in environment",
                       stack_name: 'foo',
                       camelized_stack_name: "Foo",
                       environment: 'staging',
                       camelized_environment: 'Staging',
                       name: "main",
                       camelized_name: "Main",
                       availability_zones: %w(a b),
                       instance_type: 'm4.large',
                       cluster_size: 1

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
          expect(elb_listeners).to be_empty

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
    end
  end
end
