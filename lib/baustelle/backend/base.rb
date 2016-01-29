module Baustelle
  module Backend
    class Base
      def initialize(name, options, vpc:, parent_iam_role:)
        @name = name
        @options = options
        @vpc = vpc
        @parent_iam_role = parent_iam_role
      end
    end
  end
end
