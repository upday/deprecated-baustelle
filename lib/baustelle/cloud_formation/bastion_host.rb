module Baustelle
  module CloudFormation
    module BastionHost
      extend self

      def apply(template, config, vpc:, stack_name:, parent_iam_role:)
        config.fetch('ami').each do |region, ami|
          template.add_to_region_mapping "BastionAMIs", region, 'global', ami
        end

        user_data = {
          'ssh_acl_github' => Array(config.fetch('github_ssh_keys')),
          'dns' => {
            'zone' => zone_name = config.fetch('dns_zone'),
            'hostname' => "bastion-#{stack_name.underscore.gsub('_', '-')}"
          }
        }.to_yaml

        iam_role = parent_iam_role.inherit("bastion_host", {
                                             'zone_update' => {
                                               'resource' => "arn:aws:route53:::hostedzone/#{get_zone_id(zone_name)}",
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
                            UserData: Base64.encode64(user_data),
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
    end
  end
end
