require 'spec_helper'

describe Baustelle::Jenkins::Stack do
  let(:stack_name) {
    "test-stackname"
  }
  let(:config){
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
      expect(obj).to receive(:create_list_view).with({:name=>"Baustelle test-stackname (eu-west-1)",:regex=>"baustelle-test-stackname-eu-west-1-.*"}).at_least(:once)
      expect(obj).to receive(:create_list_view).at_least(:once)
      test_object.create_views
    end

  end

end
