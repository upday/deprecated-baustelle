module Baustelle
  module Backend
    class Kinesis
      def initialize(name, options, vpc:, parent_iam_role:)
        @name = name
        @options = options
        @vpc = vpc
        @parent_iam_role = parent_iam_role
      end

      def build(template)
        template.resource "#{prefix}Stream",
                          Type: 'AWS::Kinesis::Stream',
                          Properties: {
                            ShardCount: @options.fetch('shard_count')
                          }

      end

      def output(template)
        {
          'id' => {'Ref' => "#{prefix}Stream"},
          'arn' => {'Fn::GetAtt' => ["#{prefix}Stream", "Arn"]}
        }
      end

      def prefix
        "Kinesis#{@name.camelize}"
      end
    end
  end
end
