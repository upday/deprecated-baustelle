require 'spec_helper'


describe Baustelle::Jenkins::ApplicationJobs do
  let(:jenkins_options) {
    {
      'credentials_id' => 'TestCredentials',
      'maven_settings_id' => 'TestMavenSettings'
    }
  }
  let(:raw_app_config) {
    {
      'git' => {
        'repo' => 'TestGitRepo',
        'branch' => 'Test'
      },
      'stack' => 'java-8',
      'maven' => {
        'goals_options' => 'TestMavenGoalsOptions',
        'path_to_artifact' => '/path/to/artifact'
      }
    }
  }

  let(:systemtests_disabled){
    {
      'systemtests' => false
    }
  }

  let(:systemtests_referenced){
    {
      'systemtests' => 'TestReference'
    }
  }

  let(:systemtests_config_java){
    {
      'systemtests' => {
        'git' => {
          'repo' => 'SystemTestsRepo',
          'branch' => '**/SystemTestsBranch'
        },
        'maven' => {
          'goals_options' => 'SystemtestsMavenGoalsOptions',
        }
      }
    }
  }

  let(:template) {
<<-TEMPLATE
job('<%= eb_application_name %>-<%= system_test_job_name %>') {
  steps {
    shell('echo 1')
  }
}
TEMPLATE
  }

  def generate_tests_object(systemtests_config={})
    Baustelle::Jenkins::ApplicationJobs.new(
      'TestStack',
      'TestRegion',
      jenkins_options,
      'TestEnvironment-TestHash',
      'TestApplication',
      Baustelle::Config::Application.new(raw_app_config.merge!(systemtests_config)),
      'git'
    )
  end

  describe '#generate_jobs', slow: true do
    before(:example) do
      allow(File).to receive(:read){ "#{template}"}
    end
    it 'should generate systemtest job and pipeline job' do
      expect(generate_tests_object(systemtests_config_java).generate_jobs.keys.length).to eq(2)
    end
    it 'should not generate disabled systemtest job but pipeline job' do
      expect_any_instance_of(Baustelle::Jenkins::ApplicationJobs).to_not receive(:generate_systemtests)
      expect(generate_tests_object(systemtests_disabled).generate_jobs.keys.length).to eq(1)
    end
    it 'should not generate referenced systemtest job but pipeline job' do
      expect_any_instance_of(Baustelle::Jenkins::ApplicationJobs).to_not receive(:generate_systemtests)
      expect(generate_tests_object(systemtests_referenced).generate_jobs.keys.length).to eq(1)
    end
    it 'should not generate empty systemtest job but pipeline job' do
      expect_any_instance_of(Baustelle::Jenkins::ApplicationJobs).to_not receive(:generate_systemtests)
      expect(generate_tests_object.generate_jobs.keys.length).to eq(1)
    end
  end

end
