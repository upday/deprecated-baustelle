require 'ostruct'

module Baustelle
  module CloudFormation
    class ApplicationStack
      attr_reader :canonical_name, :name

      def initialize(stack_name, app_name, bucket_name)
        @name = app_name
        @canonical_name = self.class.eb_name(stack_name, app_name)
        @bucket_name = bucket_name
        @stack_name = stack_name
        @application_template_iam_role = nil
      end

      def apply(template, vpc)
        template.resource @canonical_name,
                Type: "AWS::CloudFormation::Stack",
                Properties: {
                  Parameters: parameters = {
                    VPC: vpc.id,
                    Subnets: template.join(',', *vpc.zone_identifier),
                  }.merge!(Hash[ vpc.subnets.map { |subnet| [subnet.id['Ref'], subnet.id] }]).
                merge!(Hash[ [[@stack_name, vpc.id]] ]),
                  Tags: [
                    {Key: 'application', Value: "#{@name}"},
                    {Key: 'stack', Value: "#{@stack_name}"},
                    {Key: 'canonical-name', Value: "#{@canonical_name}"}
                  ],
                  TemplateURL: "https://s3.amazonaws.com/#{@bucket_name}/#{@canonical_name}.json",
                }
        parameters.keys.each { |name|
          if [:Subnets].include?(name)
            application_template(template).parameter(name,'CommaDelimitedList')
          else
            application_template(template).parameter(name)
          end

        }
        CloudFormation::Application.new(@stack_name, @name).apply(application_template(template))
        @application_template_iam_role = CloudFormation::IAMRole.new('', {'describe_tags' => {
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
        }).apply(application_template(template))
        template
      end

      def self.eb_name(stack_name, app_name)
        "#{stack_name}_#{app_name}".camelize
      end

      def ref(template)
        template.ref(@canonical_name)
      end

      def add_environment(template,stack_name,region,env_name,vpc,app_config,env_config,environment_backends)
        CloudFormation::EBEnvironment.apply(application_template(template),
                                            stack_name: stack_name,
                                            region: region,
                                            env_name: env_name,
                                            app_ref: application_template(template).ref(@canonical_name),
                                            app_name: @name,
                                            vpc: vpc,
                                            app_config: app_config,
                                            env_config: env_config,
                                            stack_configurations: env_config.fetch('stacks'),
                                            backends: environment_backends,
                                            base_iam_role: @application_template_iam_role,
                                            internal_dns: nil,
                                            chain_after: nil)
      end

      private

      def application_template(template)
        if not template.childs[@name]
          template.childs[@name] = CloudFormation::Template.new
        else
          template.childs[@name]
        end
      end

    end
  end
end

