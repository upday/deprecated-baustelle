shared_examples "VPC resource declaration" do
  context "with VPC" do
    it 'network' do
      expect_resource template, "foo", of_type: "AWS::EC2::VPC" do |properties|
        expect(properties[:CidrBlock]).to eq('172.31.0.0/16')
      end
    end

    it 'route table' do
      expect_resource template, "fooRouteTable",
                      of_type: "AWS::EC2::RouteTable" do |properties|
        expect(properties[:VpcId]).to eq(ref("foo"))
      end
    end

    it 'gateway' do
      expect_resource template, "fooGateway", of_type: "AWS::EC2::InternetGateway"
    end

    it 'gateway attachment' do
      expect_resource template, "fooGatewayAttachment",
                      of_type: "AWS::EC2::VPCGatewayAttachment" do |properties|
        expect(properties[:VpcId]).to eq(ref("foo"))
        expect(properties[:InternetGatewayId]).to eq(ref("fooGateway"))
      end
    end

    it 'dhcp options' do
      expect_resource template, "fooDHCPOptions",
                      of_type: 'AWS::EC2::DHCPOptions'
    end

    it 'dhcp options association' do
      expect_resource template, 'fooDHCPOptionsAssociation',
                      of_type: 'AWS::EC2::VPCDHCPOptionsAssociation'
    end

    it 'default route' do
      expect_resource template, 'fooRouteDefault',
                      of_type: 'AWS::EC2::Route' do |properties|
        expect(properties[:RouteTableId]).to eq(ref('fooRouteTable'))
        expect(properties[:GatewayId]).to eq(ref('fooGateway'))
        expect(properties[:DestinationCidrBlock]).to eq('0.0.0.0/0')
      end
    end

    {'a' => '172.31.0.0/20',
     'b' => '172.31.16.0/20'}.each do |az, cidr|
      context "for availability zone #{az}" do
        it 'subnet' do
          expect_resource template, "fooSubnet#{az.upcase}",
                          of_type: 'AWS::EC2::Subnet' do |properties|
            expect(properties[:VpcId]).to eq(ref('foo'))
            expect(properties[:CidrBlock]).to eq(cidr)
            expect(properties[:AvailabilityZone]).
              to eq({'Fn::Join' => ['', [ref('AWS::Region'), az]]})
          end
        end

        it 'route table association' do
          expect_resource template, "fooSubnet#{az.upcase}RouteTableAssociation",
                          of_type: 'AWS::EC2::SubnetRouteTableAssociation' do |properties|
            expect(properties[:SubnetId]).to eq(ref("fooSubnet#{az.upcase}"))
            expect(properties[:RouteTableId]).to eq(ref("fooRouteTable"))
          end
        end
      end
    end
  end
end
