require 'ostruct'

module Baustelle
  module CloudFormation
    module Application
      extend self

      def apply(template, name)
        template.eval do
          resource app_name = camelize(name),
                   Type: "AWS::ElasticBeanstalk::Application",
                   Properties: {
                     ApplicationName: app_name,
                     Description: "#{name} app orchestrated by the baustelle"
                   }
          ref(app_name)
        end
      end
    end
  end
end
