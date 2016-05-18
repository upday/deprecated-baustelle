require 'spec_helper'

describe Baustelle::Jenkins::Stack do

  let(:stack) {
    Baustelle::Jenkins::Stack.new(
      stack_name,
      config: config,
      region: region
    )
  }
  let(:stack_name) {
    'TestStack'
  }
  let(:region) {
    'TestRegion'
  }
  let(:config){
    YAML.load(<<-YAML)
---
applications:
  test_application:
    stack: ruby2.2-with-datadog
    instance_type: t2.small
    scale:
      min: 1
      max: 1
    elb:
      visibility: internal
environments:
  test_environment:
jenkins:
  connection:
    server_url: http://localhost:8080/
  options:
    # Jenkins Credentials: "jenkins"
    credentials_id: aa51055b-a9ad-48b2-974c-e1f4ab328fa4
    # Jenkins config-file plugin uses ids for the different config settings
    # This is the id for the global settings.xml used by maven or the sonar plugin
    maven_settings_id: org.jenkinsci.plugins.configfiles.maven.GlobalMavenSettingsConfig1422533819776

    YAML
  }
  let(:environment){
      {
        'TestEnvironment': {'TestConfig': {}}
      }

  }
  let(:application){
    {
      'TestApplication':
        {
          'disabled': false
        }
    }
  }
  let(:application_jobs){
    double = instance_double(Baustelle::Jenkins::ApplicationJobs)
  }

  let(:jenkins){
    instance_double(JenkinsApi::Client)
  }
  let(:jenkins_job){
    double(JenkinsApi::Client::Job)
  }
  let(:baustelle_config){
    class_double(Baustelle::Config).as_stubbed_const(:transfer_nested_constants => true)
  }
  let(:test_prefix){
    'TestPrefix-'
  }

  describe '#create_jobs' do
    before(:example) do
      expect(Baustelle::Jenkins::ApplicationJobs).to receive(:new) { application_jobs }
      expect(application_jobs).to receive(:job_name_prefix) { test_prefix }
      expect(stack).to receive(:jenkins) { jenkins }
      expect(jenkins).to receive(:job) { jenkins_job }
      expect(stack).to receive(:cleanup_jobs) {}
      expect(stack).to receive(:delete_views) {}
      expect(stack).to receive(:create_views) {}
    end
    it 'should execute expected methods' do
      jobs = {
        'TestJob1': 'TestXML1',
        'TestJob2': 'TestXML2'
      }
      expect(application_jobs).to receive(:generate_jobs) { jobs }
      expect(jenkins_job).to receive(:chain).with([], 'success', ['all'])
      expect(stack).to receive(:upload_jobs).with(jobs)

      stack.update
    end

    it 'should chain jobs in the correct order' do
      jobs = {
        "#{test_prefix}20-JobName"=> 'String',
        "#{test_prefix}00-JobName"=> 'String',
        "#{test_prefix}10-JobName"=> 'String'
      }
      expect(application_jobs).to receive(:generate_jobs) { jobs }
      expect(stack).to receive(:upload_jobs).with(jobs)
      expect(jenkins_job).to receive(:chain).with(
        ["#{test_prefix}00-JobName", "#{test_prefix}10-JobName", "#{test_prefix}20-JobName"],
        'success',
        ['all']
      )

      stack.update
    end

    it 'should filter out jobs which do not match the RegEx' do
      jobs = {
        "#{test_prefix}00-JobName"=> 'String',
        "#{test_prefix}JobName"=> 'String',
        "Arbitrary-Job-Name-with-dashes"=> 'String',
        "ArbitraryJobNameWithoutDashes"=> 'String'
      }
      expect(application_jobs).to receive(:generate_jobs) { jobs }
      expect(stack).to receive(:upload_jobs).with(jobs)
      expect(jenkins_job).to receive(:chain).with(
        ["#{test_prefix}00-JobName"],
        'success',
        ['all']
      )

      stack.update
    end
  end

end
