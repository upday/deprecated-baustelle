module Baustelle
  module Backend
    class External
      def initialize(name, options, vpc:, parent_iam_role:)
        @name = name
        @options = options
        @vpc = vpc
        @parent_iam_role = parent_iam_role
      end

      def build(template)
      end

      def output(template)
        @options.inject({}) do |output, (key, value)|
          output[key.to_s] = value
          output
        end
      end
    end
  end
end
