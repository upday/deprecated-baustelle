require 'spec_helper'

describe Baustelle::Jenkins::Stack, '#create_jobs' do
  let (:stack) {Baustelle::Jenkins::Stack.new('TestStack1', config: config, region: 'TestRegion1')}
  let (:config) {{
    'applications' => {
      'TestApp1' => {
        'git' => {
          'repo' => 'TestRepo1',
          'branch' => 'TestBranch1'
        },
        'stack' => 'ruby-2.2'
      },
      'TestApp2' => {
        'git' => {
          'repo' => 'TestRepo2',
          'branch' => 'TestBranch2'
        },
        'stack' => 'java-8',
        'maven' => {
          'path_to_artifact' => 'TestPath2',
          'goals_options' => 'TestGoalsOptions2'
        }
      }
    },
    'environments' => {
      'TestEnv1' => {
        'eb_application_version_source' => 'git'
      },
      'TestEnv2' => {
        'eb_application_version_source' => 'TestDependency2'
      },
      'TestEnv3' => {}
    }
  }}

  def calculate_hash(config, environment, application)
    hash_lookup = {
      'TestApp1'=>'2d75679b64',
      'TestApp2'=>'409580fd62'
    }
    temp_result = {
      :app_config=>config['applications'][application],
      :jenkins_options=>'',
      :region=>'TestRegion1',
      :eb_environment_name=>"#{environment}-#{hash_lookup[application]}",
      :eb_application_name=>"TestStack1#{application}",
      :eb_application_version_source=>config['environments'][environment].fetch('eb_application_version_source', nil)
    }
  end

  describe '#create_jobs' do
    before(:example) do
      @template = class_double('Baustelle::Jenkins::JobTemplate').
        as_stubbed_const(:transfer_nested_constants => true)
      @template_instance = instance_double('Baustelle::Jenkins::JobTemplate')
       @jenkins_instance = instance_double('JenkinsApi::Client')
      @job = instance_double('Baustelle::JenkinsApi::CLI::Job')

      allow(File).to receive(:read) {''}
      allow(stack).to receive(:jenkins_options) {''}
      allow(@template).to receive(:new) {@template_instance}
      allow(@template_instance).to receive(:render) {{}}
      allow(stack).to receive(:jenkins) {@jenkins_instance}
      allow(@jenkins_instance).to receive(:job) { @job }
      allow(@job).to receive(:chain) {}

    end
    it 'should call JobTemplate with correct params' do

      config['environments'].each do |environment,_|
        config['applications'].each do |application,_|
          expect(@template).to receive(:new).with(
            '',
            calculate_hash(config,environment,application)
          )
        end
      end


      expect(@template_instance).to receive(:render)
      expect(@jenkins_instance).to receive(:job)
      stack.send(:create_jobs)
    end
  end
end
