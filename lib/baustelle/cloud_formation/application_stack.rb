require 'ostruct'

module Baustelle
  module CloudFormation
    class ApplicationStack
      attr_reader :canonical_name, :name

      def initialize(stack_name, app_name, bucket_name)
        @name = app_name
        @canonical_name = self.class.eb_name(stack_name, app_name)
        @bucket_name = bucket_name
      end

      def apply(template)
        template.resource @canonical_name,
                Type: "AWS::CloudFormation::Stack",
                Properties: {
                  NotificationARNs: [],
                  Parameters: {},
                  Tags: [],
                  TemplateURL: "https://s3.amazonaws.com/#{@bucket_name}/#{@canonical_name}.json",
                  TimeoutInMinutes: "String"
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

