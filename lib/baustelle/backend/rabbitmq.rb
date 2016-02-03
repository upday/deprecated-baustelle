module Baustelle
  module Backend
    class RabbitMQ < Base
      def build(template)

        options.fetch('ami').each do |region, ami|
          template.add_to_region_mapping "BackendAMIs", region, ami_name, ami
        end

        prefix = "RabbitMQ#{name.camelize}"

        cname(template, [name, 'rabbitmq', 'backend'], host)

        template.resource lc = "#{prefix}LaunchConfiguration",
                          Type: 'AWS::AutoScaling::LaunchConfiguration',
                          Properties: {
                            AssociatePublicIpAddress: true,
                            KeyName: 'kitchen',
                            ImageId: template.find_in_regional_mapping('BackendAMIs', ami_name),
                            InstanceType: options.fetch('instance_type',
                                                        default_instance_type),
                            SecurityGroups: [template.ref("GlobalSecurityGroup")],
                            IamInstanceProfile: template.ref(@parent_iam_role.instance_profile_name)
                          }

        template.resource elb = "#{prefix}ELB",
                          Type: 'AWS::ElasticLoadBalancing::LoadBalancer',
                          Properties: {
                            Subnets: vpc.zone_identifier,
                            Scheme: 'internal',
                            SecurityGroups: [template.ref('ELBSecurityGroup')],
                            CrossZone: true,
                            Listeners: [
                              {InstancePort: 5672, InstanceProtocol: 'tcp',
                               LoadBalancerPort: 5672, Protocol: 'tcp'},
                              {InstancePort: 15672, InstanceProtocol: 'http',
                               LoadBalancerPort: 80, Protocol: 'http'}
                            ],
                            Tags: [
                              {Key: 'BaustelleBackend', Value: 'RabbitMQ'},
                              {Key: 'BaustelleName', Value: name}
                            ],
                            HealthCheck: {
                              Target: "HTTP:15672/",
                              HealthyThreshold: "3",
                              UnhealthyThreshold: "3",
                              Interval: "10",
                              Timeout: "5"
                            },
                          }

        template.resource "#{prefix}ASG",
                          Type: 'AWS::AutoScaling::AutoScalingGroup',
                          Properties: {
                            AvailabilityZones: vpc.availability_zones,
                            MinSize: options.fetch('cluster_size'),
                            MaxSize: options.fetch('cluster_size'),
                            DesiredCapacity: options.fetch('cluster_size'),
                            LoadBalancerNames: [template.ref(elb)],
                            VPCZoneIdentifier: vpc.zone_identifier,
                            LaunchConfigurationName: template.ref(lc),
                            Tags: [
                              {PropagateAtLaunch: true, Key: 'BaustelleBackend', Value: 'RabbitMQ'},
                              {PropagateAtLaunch: true, Key: 'BaustelleName', Value: name.camelize},
                              {PropagateAtLaunch: true, Key: 'Name', Value: prefix},
                            ]
                          },
                          UpdatePolicy: {
                            AutoScalingRollingUpdate: {
                              MaxBatchSize: 1,
                              MinInstancesInService: 1,
                              PauseTime: 'PT3M'
                            }
                          }
      end

      def output(template)
        {
          'url' => {'Fn::Join' => ['', ['amqp://yana:_yana101_@', host, ':5672']] },
          'host' => host,
          'port' => 5672,
          'username' => 'yana',
          'password' => '_yana101_'
        }
      end

      private

      attr_reader :name, :options, :vpc

      def host
        {'Fn::GetAtt' => ["RabbitMQ#{name.camelize}ELB", 'DNSName']}
      end

      def ami_name
        "rabbit_mq_#{name}"
      end

      def default_instance_type
        't2.small'
      end
    end
  end
end
