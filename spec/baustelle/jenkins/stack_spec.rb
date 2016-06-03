require 'spec_helper'

describe Baustelle::Jenkins::Stack do
  let(:stack_name) {
    "test-stackname"
  }
  let(:config){
YAML.load(<<-YAML)
---
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

environments:
  production:
    applications:
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
  let(:region){
    'eu-west-1'
  }

  def generate_test_object(obj)
    test_obj = Baustelle::Jenkins::Stack.new(
      stack_name,
      config: config,
      region: region
      )
    allow(test_obj).to receive_message_chain(:jenkins,:view){obj}
    test_obj
  end

  describe '#create_views' do

    it 'create the correct views' do
      obj = double()
      test_object = generate_test_object(obj)
      expect(obj).to receive(:create_list_view).with({:name=>"Baustelle test-stackname (eu-west-1)",:regex=>"baustelle-test-stackname-eu-west-1-.*"})
      expect(obj).to receive(:create_list_view).at_least(:once)
      test_object.create_views
    end

  end

end
