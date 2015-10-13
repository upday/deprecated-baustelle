require 'spec_helper'
require_relative 'stack_template/vpc'

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

applications:
  hello_world:
    stack: ruby
    instance_type: t2.micro
    scale:
      min: 2
      max: 4
    config:
      RAILS_ENV: production
environments:
  production: {}
  staging:
    applications:
      hello_world:
        scale:
          min: 1
          max: 1
        config:
          RAILS_ENV: staging
    YAML
  }

  def expect_resource(template, resource_name, of_type: nil)
    resource = template[:Resources][resource_name]
    expect(resource).to be
    expect(resource[:Type]).to eq(of_type) if of_type
    yield resource[:Properties], resource if block_given?
  end

  def ref(name)
    {'Ref' => name}
  end

  describe '#build' do
    subject { stack_template.build("foo") }

    context "returns template" do
      let(:template) { subject.as_json }

      include_examples "VPC resource declaration"
    end
  end
end
