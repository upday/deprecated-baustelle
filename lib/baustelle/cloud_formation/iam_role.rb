module Baustelle
  module CloudFormation
    class IAMRole
      def initialize(name, statements)
        @name = name
        @statements = statements
      end

      def role_name
        "IAMRole#{@name.camelize}"
      end

      def instance_profile_name
        "IAMInstanceProfile#{@name.camelize}"
      end

      def to_str
        role_name
      end

      def inherit(name, statements)
        self.class.new(name, @statements.deep_merge(statements))
      end

      def apply(template)
        template.resource role_name,
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
                            Policies: @statements.map { |name, options|
                              {
                                PolicyName: role_name + name.to_s.camelize,
                                PolicyDocument: {
                                  Version: "2012-10-17",
                                  Statement: [
                                    {
                                      Effect: options.fetch('effect', 'Allow'),
                                      Action: options.fetch('action'),
                                      Resource: options.fetch('resource', '*')
                                    }
                                  ]
                                }
                              }
                            }
                          }

        template.resource instance_profile_name,
                          Type: 'AWS::IAM::InstanceProfile',
                          Properties: {
                            Path: '/',
                            Roles: [template.ref(role_name)]
                          }

        self
      end
    end
  end
end
