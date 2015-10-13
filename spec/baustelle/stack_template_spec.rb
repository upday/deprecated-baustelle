require 'spec_helper'

describe Baustelle::StackTemplate do
  let(:stack_template) { Baustelle::StackTemplate.new(config) }

  let(:config) {
    YAML.load(<<-YAML)
---
stacks:
  ruby:
    solution: Ruby AWS EB Solution

vpc:
  cidr: 172.31.0.0/16
  subnets:
    a: 172.31.0.0/20
    b: 172.31.16.0/20

applications:
  hello_world:
    stack: ruby
    instance_type: t2.micro
    scale:
      min: 2
      max: 4
    config:
      RAILS_ENV: production
environments:
  production: {}
  staging:
    applications:
      hello_world:
        scale:
          min: 1
          max: 1
        config:
          RAILS_ENV: staging
    YAML
  }

  def expect_resource(template, resource_name, of_type: nil)
    resource = template[:Resources][resource_name]
    expect(resource).to be
    expect(resource[:Type]).to eq(of_type) if of_type
    yield resource[:Properties], resource if block_given?
  end

  def ref(name)
    {'Ref' => name}
  end

  describe '#build' do
    subject { stack_template.build("foo") }

    context "returns template" do
      let(:template) { subject.as_json }

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
  end
end
