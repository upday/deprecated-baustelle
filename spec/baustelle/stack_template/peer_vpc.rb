shared_examples "Peer VPC" do |vpc_id:, cidr:, name:, camelized_name:|
  context "peers with #{name} VPC" do
    it "creates peering connection" do
      expect_resource template, "PeerVPC#{camelized_name}PeeringConnection",
                      of_type: "AWS::EC2::VPCPeeringConnection" do |properties|
        expect(properties[:VpcId]).to eq(ref('foo'))
        expect(properties[:PeerVpcId]).to eq(vpc_id)
      end
    end

    it "creates route" do
      expect_resource template, "PeerVPC#{camelized_name}Route",
                      of_type: 'AWS::EC2::Route' do |properties|
        expect(properties[:DestinationCidrBlock]).to eq(cidr)
        expect(properties[:VpcPeeringConnectionId]).
          to eq(ref("PeerVPC#{camelized_name}PeeringConnection"))
        expect(properties[:RouteTableId]).to eq(ref('fooRouteTable'))
      end
    end

    it "outputs peering connection id" do
      expect(template[:Outputs]["PeeringConnectionVPC#{camelized_name}"]).
        to eq({
                Description: "Peering connection ID for #{name} VPC",
                Value: ref("PeerVPC#{camelized_name}PeeringConnection")
              })
    end
  end
end
