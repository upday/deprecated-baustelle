require 'ostruct'

module Baustelle
  module CloudFormation
    class Application

      attr_reader :canonical_name, :name

      def initialize(stack_name, app_name)
        @name = app_name
        @canonical_name = self.class.eb_name(stack_name, app_name)
      end

      def apply(template)
        template.resource @canonical_name,
                 Type: "AWS::ElasticBeanstalk::Application",
                 Properties: {
                   ApplicationName: @canonical_name,
                   Description: "#{@canonical_name} app orchestrated by the baustelle"
                 }
      end

      def self.eb_name(stack_name, app_name)
        "#{stack_name}_#{app_name}".camelize
      end

      def ref(template)
        template.ref(@canonical_name)
      end

    end
  end
end
