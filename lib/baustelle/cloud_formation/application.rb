require 'ostruct'

module Baustelle
  module CloudFormation
    module Application
      extend self

      def apply(template, name)
        template.resource app_name = name.camelize,
                 Type: "AWS::ElasticBeanstalk::Application",
                 Properties: {
                   ApplicationName: app_name,
                   Description: "#{name} app orchestrated by the baustelle"
                 }
        template.ref(app_name)
      end
    end
  end
end
