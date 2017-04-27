module Baustelle
  module Backend
    class Base
      def initialize(name, options, vpc:, parent_iam_role:,
                     internal_dns:, env_name:)
        @name = name
        @options = options
        @vpc = vpc
        @parent_iam_role = parent_iam_role
        @internal_dns = internal_dns
        @env_name = env_name
      end

      private

      attr_reader :name, :options, :vpc, :parent_iam_role, :internal_dns
    end
  end
end
