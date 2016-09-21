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
      end

      def apply(template, vpc)
        template.resource @canonical_name,
                Type: "AWS::CloudFormation::Stack",
                Properties: {
                  NotificationARNs: [],
                  Parameters: {
                    VPC: vpc.id,
                    Subnets: template.join(',', *vpc.zone_identifier),
                  },
                  Tags: [
                    {Key: 'application', Value: "#{@name}"},
                    {Key: 'stack', Value: "#{@stack_name}"},
                    {Key: 'canonical-name', Value: "#{@canonical_name}"}
                  ],
                  TemplateURL: "https://s3.amazonaws.com/#{@bucket_name}/#{@canonical_name}.json",
                }
      end

      def self.eb_name(stack_name, app_name)
        "#{stack_name}_#{app_name}_stack".camelize
      end

      def ref(template)
        template.ref(@canonical_name)
      end

    end
  end
end

