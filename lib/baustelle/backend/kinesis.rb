module Baustelle
  module Backend
    class Kinesis
      def initialize(name, options, vpc:)
        @name = name
        @options = options
        @vpc = vpc
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
          'id' => {'Ref' => "#{prefix}Stream"}
        }
      end

      def prefix
        "Kinesis#{@name.camelize}"
      end
    end
  end
end