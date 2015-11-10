require "spec_helper"
require 'ostruct'

describe Baustelle::CloudFormation::PeerVPC do
  describe "#list" do
    let(:outputs) {
      [
        OpenStruct.new(output_key: "foo", output_value: "bar"),
        OpenStruct.new(output_key: "PeeringConnectionVPCProd",
                       output_value: "pcx-123456")
      ]
    }

    it "returns hash with VPC names as keys and peeting connection IDs as values" do
      result = Baustelle::CloudFormation::PeerVPC.list("stack", outputs: outputs)
      expect(result).to eq({"Prod" => "pcx-123456"})
    end
  end
end
