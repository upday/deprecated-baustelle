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
  hello_world:
    stack: ruby
    instance_type: t2.small
    scale:
      min: 2
      max: 4

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

end
