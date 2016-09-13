module Baustelle
  class StackTemplate
    PARALLEL_EB_UPDATES = ENV.fetch('PARALLEL_EB_UPDATES', 4).to_i

    def initialize(config)
      @config = config
    end

    def childs
      []
    end

    def build(name, region, template: CloudFormation::Template.new)
      # Prepare VPC
      vpc = CloudFormation::VPC.apply(template, vpc_name: name,
                                      cidr_block: config.fetch('vpc').fetch('cidr'),
                                      subnets: config.fetch('vpc').fetch('subnets'))

      peer_vpcs = config.fetch('vpc').fetch('peers', {}).map do |name, peer_config|
        CloudFormation::PeerVPC.apply(template, vpc, name,
                                      peer_config)
      end

      internal_dns_zones = [CloudFormation::InternalDNS.zone(template, stack_name: name,
                                                            vpcs: [vpc],
                                                            root_domain: "baustelle.internal"),
                           CloudFormation::InternalDNS.zone(template, stack_name: name,
                                                            vpcs: peer_vpcs,
                                                            root_domain: "#{name}.#{region}.baustelle.internal",
                                                            type: 'Peering')]


      template.resource "GlobalSecurityGroup",
                        Type: "AWS::EC2::SecurityGroup",
                        Properties: {
                          VpcId: vpc.id,
                          GroupDescription: "#{name} baustelle stack global Security Group",
                          SecurityGroupIngress: [
                            {IpProtocol: 'tcp', FromPort: 80, ToPort: 80, SourceSecurityGroupId: template.ref('ELBSecurityGroup')},
                          ] + ([vpc] + peer_vpcs).map { |vpc|
                            {IpProtocol: 'tcp', FromPort: 0, ToPort: 65535, CidrIp: vpc.cidr} }
                        }

      template.resource "ELBSecurityGroup",
                        Type: "AWS::EC2::SecurityGroup",
                        Properties: {
                          VpcId: vpc.id,
                          GroupDescription: "#{name} baustelle stack ELB Security Group",
                          SecurityGroupIngress: [
                            {IpProtocol: 'tcp', FromPort: 0, ToPort: 65535, CidrIp: '0.0.0.0/0'}
                          ]
                        }

      global_iam_role = CloudFormation::IAMRole.new('', {'describe_tags' => {
                                                           'action' => 'ec2:DescribeTags'
                                                         },
                                                         'describe_instances' => {
                                                           'action' => 'ec2:DescribeInstances'
                                                         },
                                                         'elastic_beanstalk_bucket_access' => {
                                                           'action' => ['s3:Get*', 's3:List*', 's3:PutObject'],
                                                           'resource' => [
                                                             "arn:aws:s3:::elasticbeanstalk-*-*",
                                                             "arn:aws:s3:::elasticbeanstalk-*-*/*",
                                                             "arn:aws:s3:::elasticbeanstalk-*-*-*",
                                                             "arn:aws:s3:::elasticbeanstalk-*-*-*/*"
                                                           ]
                                                         }
                                                        }).apply(template)

      if bastion_config = config['bastion']
        Baustelle::CloudFormation::BastionHost.apply(template, bastion_config, vpc: vpc, stack_name: name, parent_iam_role: global_iam_role)
      end

      applications = Baustelle::Config.applications(config).map do |app_name|
        environment_layouts = Baustelle::Config.environments(config).map { |env_name|
          env_config = Baustelle::Config.for_environment(config, env_name)
          app_config = Baustelle::Config.app_config(env_config, app_name)
          app_config.template_layout
        }.uniq
        if environment_layouts.length != 1
          $stderr.puts "The setting template_layout must not be overwritten in any environment"
          raise "The setting template_layout must not be overwritten in any environment"
        end
        environment_layout = environment_layouts[0]
        case environment_layout
          when 'old'
            app = CloudFormation::Application.new(name, app_name)
            app.apply(template)
          when 'new'
            app = CloudFormation::ApplicationStack.new(name, app_name)
            raise "new template_layout is not supported yet"
        end
        app
      end

      # It is used to chain updates. There is high iikehood we hit AWS API rate limit
      # if we create/update all environments at once
      previous_eb_env = Array.new(PARALLEL_EB_UPDATES) { nil }

      # For every environemnt
      Baustelle::Config.environments(config).each do |env_name|
        env_config = Baustelle::Config.for_environment(config, env_name)

        # Create backends

        environment_backends = Hash.new { |h,k| h[k] = {} }

        (env_config['backends'] || {}).inject(environment_backends) do |acc, (type, backends)|
          backend_klass = Baustelle::Backend.const_get(type)

          backends.each do |backend_name, options|
            backend_full_name = [env_name, backend_name].join('_')
            acc[type][backend_name] = backend = backend_klass.new(backend_full_name, options, vpc: vpc,
                                                                  parent_iam_role: global_iam_role,
                                                                  internal_dns: internal_dns_zones)
            backend.build(template)
          end

          environment_backends
        end

        # Create applications

        applications.each.with_index do |app, index|
          app_config = Baustelle::Config.app_config(env_config, app.name)

          unless app_config.disabled?
            if app_config.template_layout == 'old'
              resource_name = CloudFormation::EBEnvironment.apply(template,
                                                                  stack_name: name,
                                                                  region: region,
                                                                  env_name: env_name,
                                                                  app_ref: app.ref(template),
                                                                  app_name: app.name,
                                                                  vpc: vpc,
                                                                  app_config: app_config,
                                                                  env_config: env_config,
                                                                  stack_configurations: env_config.fetch('stacks'),
                                                                  backends: environment_backends,
                                                                  base_iam_role: global_iam_role,
                                                                  internal_dns: internal_dns_zones,
                                                                  chain_after: previous_eb_env[index % previous_eb_env.size])
              previous_eb_env[index % previous_eb_env.size] = resource_name
            elsif app_config.template_layout == 'new'
              puts "template_layout => new is not supported yet"
              raise "new template_layout is not supported yet"
            end
          end
        end
      end
      template
    end

    private

    attr_reader :config
  end
end
