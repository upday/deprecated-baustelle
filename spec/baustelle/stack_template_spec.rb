require 'spec_helper'
require_relative 'stack_template/vpc'
require_relative 'stack_template/application'
require_relative 'stack_template/backend/rabbitmq'

describe Baustelle::StackTemplate do
  let(:stack_template) { Baustelle::StackTemplate.new(config) }

  let(:config) {
    YAML.load(<<-YAML)
---
stacks:
  ruby:
    solution: Ruby AWS EB Solution

vpc:
  cidr: 172.31.0.0/16
  subnets:
    a: 172.31.0.0/20
    b: 172.31.16.0/20

backends:
  RabbitMQ:
    main:
      ami:
        us-east-1: ami-123456
      instance_type: m4.large
      cluster_size: 4

applications:
  hello_world:
    stack: ruby
    instance_type: t2.small
    scale:
      min: 2
      max: 4
    config:
      RAILS_ENV: production
environments:
  production: {}
  staging:
    backends:
      RabbitMQ:
        main:
          cluster_size: 1
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
                            "expected #{resource_name} to be presend. Available resource names #{template[:Resources].keys}"
    expect(resource[:Type]).to eq(of_type) if of_type
    yield resource[:Properties], resource if block_given?
  end

  def ref(name)
    {'Ref' => name}
  end

  describe '#build' do
    subject { stack_template.build("foo") }

    context "returns template" do
      let(:template) { (subject.as_json) }

      include_examples "VPC resource declaration"

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
    end
  end
end
