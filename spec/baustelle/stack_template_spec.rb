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
    initial_acc = Hash.new { |h, k| h[k] = {} }
    option_settings.inject(initial_acc) do |acc, entry|
      acc[entry[:Namespace]][entry[:OptionName]] = entry[:Value]
      entry[:Namespace]
      acc[entry[:Namespace]]
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

      it 'links RabbitMQ server to the app' do
        expect_resource template, "HelloWorldEnvProduction" do |properties|
          option_settings = group_option_settings(properties[:OptionSettings])
          app_env = option_settings["aws:elasticbeanstalk:application:environment"]
          expect(app_env["RABBITMQ_URL"]).
            to eq({'Fn::Join' =>
                   ['', [
                      'amqp://',
                      {'Fn::GetAtt' => [ref("RabbitMQProductionMainELB"), 'DNSName']},
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
    end
  end
end
