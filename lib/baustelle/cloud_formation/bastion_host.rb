module Baustelle
  module CloudFormation
    module BastionHost
      extend self

      def apply(template, config, vpc:, stack_name:, parent_iam_role:,
                dns_zone:)
        config.fetch('ami').each do |region, ami|
          template.add_to_region_mapping "BastionAMIs", region, 'global', ami
        end

        user_data = generate_user_data(template, config: config,
                                       dns_zone: dns_zone,
                                       stack_name: stack_name)

        iam_role = parent_iam_role.inherit("bastion_host", {
                                             'zones_update' => {
                                               'resource' => user_data.dns_config.map { |dns|
                                                 zone_id = dns['zone_id'] || get_zone_id(dns['zone'])
                                                 "arn:aws:route53:::hostedzone/#{zone_id}"
                                               }.uniq,
                                               'action' => 'route53:ChangeResourceRecordSets'
                                             },
                                             'zones_list' => {
                                               'action' => 'route53:ListHostedZones'
                                             }
                                           }).
                   apply(template)

        template.resource "BastionSecurityGroup",
                          Type: "AWS::EC2::SecurityGroup",
                          Properties: {
                            GroupDescription: "bastion host security group",
                            VpcId: vpc.id,
                            SecurityGroupIngress: [
                              {IpProtocol: 'tcp', FromPort: 22, ToPort: 22, CidrIp: '0.0.0.0/0'},
                              {IpProtocol: 'tcp', FromPort: 8888, ToPort: 8888, CidrIp: vpc.cidr}
                            ]
                          }

        template.resource "BastionLaunchConfiguration",
                          Type: "AWS::AutoScaling::LaunchConfiguration",
                          Properties: {
                            AssociatePublicIpAddress: true,
                            InstanceType: config.fetch('instance_type'),
                            IamInstanceProfile: template.ref(iam_role.instance_profile_name),
                            ImageId: template.find_in_regional_mapping('BastionAMIs', 'global'),
                            UserData: user_data.encoded,
                            SecurityGroups: [template.ref('GlobalSecurityGroup'),
                                             template.ref('BastionSecurityGroup')]
                          }

        template.resource "BastionASG",
                          Type: "AWS::AutoScaling::AutoScalingGroup",
                          Properties: {
                            AvailabilityZones: vpc.availability_zones,
                            MinSize: 1,
                            MaxSize: 1,
                            DesiredCapacity: 1,
                            LaunchConfigurationName: template.ref('BastionLaunchConfiguration'),
                            VPCZoneIdentifier: vpc.zone_identifier,
                            Tags: [
                              {PropagateAtLaunch: true, Key: 'Name', Value: "BaustelleBastion#{stack_name.camelize}"},
                            ]

                          },
                          UpdatePolicy: {
                            AutoScalingRollingUpdate: {
                              MaxBatchSize: 1
                            }
                          }
      end

      # TODO: use AWS SDK to get zone ID
      def get_zone_id(*)
        '*'
      end

      def generate_user_data(template, config:, dns_zone:, stack_name:)
        head, tail = {
          'ssh_acl_github' => Array(config.fetch('github_ssh_keys')),
          'dns' => dns_config = [
            {
              'zone' => dns_zone.domain,
              'zone_id' => divider = 'INTERNAL_ZONE_ID',
              'hostname' => "bastion"
            },
            {
              'zone' => config.fetch('dns_zone'),
              'zone_id' => nil,
              'hostname' => "bastion-#{stack_name.underscore.gsub('_', '-')}"
            }
          ]
        }.to_yaml.split(divider)

        internal_zone_id = template.ref('InternalDNSZone')

        user_data = {
          'Fn::Base64' => template.join('', head, internal_zone_id, tail)
        }

        OpenStruct.new(encoded: user_data, dns_config: dns_config)
      end
    end
  end
end
