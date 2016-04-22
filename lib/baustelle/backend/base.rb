module Baustelle
  module Backend
    class Base
      def initialize(name, options, vpc:, parent_iam_role:,
                     internal_dns:)
        @name = name
        @options = options
        @vpc = vpc
        @parent_iam_role = parent_iam_role
        @internal_dns = internal_dns
      end

      private

      attr_reader :name, :options, :vpc, :parent_iam_role, :internal_dns
    end
  end
end
