require 'spec_helper'


describe Baustelle::Jenkins::ApplicationJobs do
  let(:application_jobs) {
    Baustelle::Jenkins::ApplicationJobs.new(
      'TestStack',
      'TestRegion',
      jenkins_options,
      'TestEnvironment-TestHash',
      'TestApplication',
      app_config,
      'git'
    )
  }
  let(:jenkins_options) {
    {
      'credentials_id' => 'TestCredentials',
      'maven_settings_id' => 'TestMavenSettings'
    }
  }
  let(:app_config) {
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

job('TestJob') {
  steps {
    shell('echo 1')
  }
}
TEMPLATE
}
  def generate_tests_object(systemtests_config)
    Baustelle::Jenkins::ApplicationJobs.new(
      'TestStack',
      'TestRegion',
      jenkins_options,
      'TestEnvironment-TestHash',
      'TestApplication',
      app_config.merge!(systemtests_config),
      'git'
    )
  end

  describe '#generate_systemtests' do
    before(:example) do
      allow(File).to receive(:read){ "#{template}"}
    end
    it 'should generate systemtest jobs' do
      expect(generate_tests_object(systemtests_config_java).generate_systemtests.keys.length).to eq(1)
    end
    it 'should not generate disabled systemtest jobs' do
      expect(generate_tests_object(systemtests_disabled).generate_systemtests.keys.length).to eq(0)
    end
    it 'should not generate referenced systemtest jobs' do
      expect(generate_tests_object(systemtests_referenced).generate_systemtests.keys.length).to eq(0)
    end
    it 'should not generate empty systemtest jobs' do
      expect(generate_tests_object({}).generate_systemtests.keys.length).to eq(0)
    end
  end

  describe '#generate_pipeline' do
    before(:example) do
      allow(File).to receive(:read){ "#{template}"}
    end
    it 'should generate job pipeline' do
      expect(application_jobs.generate_pipeline.keys.length).to eq(1)
    end
  end
end
