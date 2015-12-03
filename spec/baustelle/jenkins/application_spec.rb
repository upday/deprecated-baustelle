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
      },
      'systemtests' => {
        'git' => {
          'repo' => 'SystemTestRepo',
          'branch' => 'SystemTestBranch'
        },
        'maven' => 'SystemTestMavenGoalsOptions'
      }

    }
  }
  let(:template) {
<<-TEMPLATE
//<% @options.select{|key,value| value != nil}.each do |key,value| %>
//<%= key %>: <%= value.to_json %>
//<% end %>

job('TestJob') {
  steps {
    shell('echo 1')
  }
}
TEMPLATE
}

  describe '#generate_systemtests' do
    before(:example) do
      allow(File).to receive(:read){ "#{template}"}
    end
    it 'should generate systemtest jobs' do
      expect(application_jobs.generate_systemtests.keys.length).to eq(1)
    end
  end
  describe '#generate_pipeline' do
    before(:example) do
      allow(File).to receive(:read){ "#{template}"}
    end
    it 'should generate systemtest jobs' do
      expect(application_jobs.generate_pipeline.keys.length).to eq(1)
    end
  end
end
