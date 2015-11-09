module Baustelle
  class StackTemplate
    def initialize(config)
      @config = config
    end

    def build(name, template: CloudFormation::Template.new)
      # Prepare VPC
      vpc = CloudFormation::VPC.apply(template, vpc_name: name,
                                      cdir_block: config.fetch('vpc').fetch('cidr'),
                                      subnets: config.fetch('vpc').fetch('subnets'))

      peer_vpcs = config.fetch('vpc').fetch('peers', {}).map do |name, peer_config|
        CloudFormation::PeerVPC.apply(template, vpc, name,
                                      peer_config)
      end

      template.resource "GlobalSecurityGroup",
                        Type: "AWS::EC2::SecurityGroup",
                        Properties: {
                          VpcId: vpc.id,
                          GroupDescription: "#{name} baustelle stack global Security Group",
                          SecurityGroupIngress: [
                            {IpProtocol: 'tcp', FromPort: 0, ToPort: 65535, CidrIp: '0.0.0.0/0'}
                          ]
                        }

      template.resource "IAMRole",
                        Type: "AWS::IAM::Role",
                        Properties: {
                          Path: '/',
                          AssumeRolePolicyDocument: {
                            Version: '2012-10-17',
                            Statement: [
                              {
                                Effect: 'Allow',
                                Principal: {Service: ['ec2.amazonaws.com']},
                                Action: ['sts:AssumeRole']
                              }
                            ]
                          },
                          Policies: [
                            {
                              PolicyName: 'DescribeTags',
                              PolicyDocument: {
                                Version: '2012-10-17',
                                Statement: [
                                  {
                                    Effect: 'Allow',
                                    Action: "ec2:DescribeTags",
                                    Resource: "*"
                                  }
                                ]
                              }
                            },
                            {
                              PolicyName: 'DescribeInstances',
                              PolicyDocument: {
                                Version: '2012-10-17',
                                Statement: [
                                  {
                                    Effect: 'Allow',
                                    Action: 'ec2:DescribeInstances',
                                    Resource: '*'
                                  }
                                ]
                              }
                            }
                          ]
                        }

      template.resource "IAMInstanceProfile",
                        Type: 'AWS::IAM::InstanceProfile',
                        Properties: {
                          Path: '/',
                          Roles: [template.ref('IAMRole')]
                        }

      # Create Beanstalk applications
      applications = Baustelle::Config.applications(config).map do |app_name|
        canonical_app_name = [name, app_name].join('_')
        OpenStruct.new(name: app_name,
                       canonical_name: canonical_app_name,
                       ref: CloudFormation::Application.apply(template, canonical_app_name))
      end

      # For every environemnt
      Baustelle::Config.environments(config).each do |env_name|
        env_config = Baustelle::Config.for_environment(config, env_name)

        # Create backends

        environment_backends = Hash.new { |h,k| h[k] = {} }

        (env_config['backends'] || {}).inject(environment_backends) do |acc, (type, backends)|
          backend_klass = Baustelle::Backend.const_get(type)

          backends.each do |backend_name, options|
            backend_full_name = [env_name, backend_name].join('_')
            acc[type][backend_name] = backend = backend_klass.new(backend_full_name, options, vpc: vpc)
            backend.build(template)
          end

          environment_backends
        end

        # Create applications
        applications.each do |app|
          app_config = Baustelle::Config.app_config(env_config, app.name)

          if not app_config.fetch('disabled', false)
            CloudFormation::EBEnvironment.apply(template,
                                                stack_name: name,
                                                env_name: env_name,
                                                app_ref: app.ref,
                                                app_name: app.name,
                                                vpc: vpc,
                                                app_config: app_config,
                                                stack_configurations: env_config.fetch('stacks'),
                                                backends: environment_backends)
          end
        end
      end
      template
    end

    private

    attr_reader :config
  end
end
