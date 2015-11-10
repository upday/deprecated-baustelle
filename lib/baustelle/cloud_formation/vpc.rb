require 'ostruct'

module Baustelle
  module CloudFormation
    module VPC
      extend self

      def apply(template, vpc_name:, cdir_block:, subnets:)

        template.resource vpc_name, :Type => 'AWS::EC2::VPC', :Properties => {
                            :Tags => [
                              {
                                :Key => 'Name',
                                :Value => vpc_name,
                              },
                            ],
                            :InstanceTenancy => 'default',
                            :EnableDnsSupport => true,
                            :EnableDnsHostnames => true,
                            :CidrBlock => cdir_block,
                          }

        template.resource route_table = "#{vpc_name}RouteTable", :Type => 'AWS::EC2::RouteTable', :Properties => {
                            :VpcId => template.ref(vpc_name),
                            :Tags => [
                              {
                                :Key => 'Name',
                                :Value => route_table
                              }
                            ]
                          }

        template.resource gateway = "#{vpc_name}Gateway",
                          :Type => 'AWS::EC2::InternetGateway',
                          :Properties => {
                            :Tags => [
                              {
                                :Key => 'Name',
                                :Value => gateway
                              }
                            ],
                          }

        template.resource "#{gateway}Attachment",
                          :Type => 'AWS::EC2::VPCGatewayAttachment',
                          :Properties => {
                            :VpcId => template.ref(vpc_name),
                            :InternetGatewayId => template.ref(gateway),
                          }

        template.resource dhcp_options = "#{vpc_name}DHCPOptions",
                          :Type => 'AWS::EC2::DHCPOptions',
                          :Properties => {
                            :DomainName => template.join('.', template.ref('AWS::Region'), 'compute', 'internal'),
                            :DomainNameServers => [ 'AmazonProvidedDNS' ],
                            :Tags => [
                              {
                                :Key => 'Name',
                                :Value => dhcp_options
                              }
                            ]
                          }

        template.resource "#{dhcp_options}Association",
                          :Type => 'AWS::EC2::VPCDHCPOptionsAssociation',
                          :Properties => {
                            :DhcpOptionsId => template.ref(dhcp_options),
                            :VpcId => template.ref(vpc_name),
                          }

        template.resource "#{vpc_name}RouteDefault", :Type => 'AWS::EC2::Route', :Properties => {
                            :RouteTableId => template.ref(route_table),
                            :GatewayId => template.ref(gateway),
                            :DestinationCidrBlock => '0.0.0.0/0',
                          }

        subnets.each do |az, cdir|
          subnet_name = "#{vpc_name}Subnet#{az.upcase}"

          template.resource subnet_name,
                            :Type => 'AWS::EC2::Subnet',
                            :Properties => {
                              :VpcId => template.ref(vpc_name),
                              :CidrBlock => cdir,
                              :AvailabilityZone => template.join('', template.ref('AWS::Region'), az),
                              :Tags => [
                                {
                                  :Key => 'Name',
                                  :Value => subnet_name
                                },
                              ],
                            }

          template.resource "#{subnet_name}RouteTableAssociation",
                            :Type => 'AWS::EC2::SubnetRouteTableAssociation',
                            :Properties => {
                              :SubnetId => template.ref(subnet_name),
                              :RouteTableId => template.ref(route_table),
                            }

        end

        OpenStruct.new(id: template.ref(vpc_name),
                       name: vpc_name,
                       subnets: subs = subnets.keys.map { |az|
                         OpenStruct.new(id: template.ref("#{vpc_name}Subnet#{az.upcase}"),
                                        az: az)
                       },
                       availability_zones: subs.map { |subnet|
                         template.join('', template.ref('AWS::Region'), subnet.az)
                       },
                       zone_identifier: subs.map(&:id))
      end
    end
  end
end
