require 'spec_helper'

describe Baustelle::CloudFormation::RemoteTemplate do
  describe '#call' do
    let(:template) { Baustelle::CloudFormation::RemoteTemplate.
                     new('baustelle', region: 'us-east-1', bucket: bucket) }

    let(:bucket) { double(object: object, clear!: nil, name: 'bautelle-workspace-bucket') }
    let(:object) { spy(put: nil, public_url: 'url') }
    let(:cloudformation_template) { spy('CloudFormation::Template', childs: [], to_json: '{}') }
    let(:stack_template) { spy('Baustelle::StackTemplate', build: cloudformation_template) }


    it 'yields file url' do
      expect { |block| template.call(stack_template, &block) }.
        to yield_with_args("url")
    end

    it 'puts the content in the remote file' do
      expect(object).to receive(:put).with(body: '{}')
      template.call(stack_template) {}
    end

    it 'deletes the remote file after the block' do
      template.call(stack_template) do
        expect(bucket).not_to have_received(:clear!)
      end
      expect(bucket).to have_received(:clear!)
    end
  end
end
