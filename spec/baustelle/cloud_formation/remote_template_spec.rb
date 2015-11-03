require 'spec_helper'

describe Baustelle::CloudFormation::RemoteTemplate do
  describe '#call' do
    let(:template) { Baustelle::CloudFormation::RemoteTemplate.
                     new(region: 'us-east-1', bucket: bucket) }

    let(:bucket) { double(object: object) }
    let(:object) { spy(put: nil, public_url: 'url', delete: nil) }

    it 'yields file url' do
      expect { |block| template.call("{}", &block) }.
        to yield_with_args("url")
    end

    it 'puts the content in the remote file' do
      expect(object).to receive(:put).with(body: '{}')
      template.call("{}") {}
    end

    it 'deletes the remote file after the block' do
      template.call("{}") do
        expect(object).not_to have_received(:delete)
      end
      expect(object).to have_received(:delete)
    end
  end
end
