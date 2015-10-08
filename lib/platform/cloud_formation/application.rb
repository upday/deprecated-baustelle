require 'ostruct'

module Platform
  module CloudFormation
    module Application
      extend self

      def apply(template, name)
        template.eval do
          resource app_name = "#{camelize(name)}",
                   Type: "AWS::ElasticBeanstalk::Application",
                   Properties: {
                     ApplicationName: name,
                     Description: "#{name} app orchestrated by the platform"
                   }
          ref(app_name)
        end
      end
    end
  end
end
