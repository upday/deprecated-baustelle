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

      def cname(template, name, target, **kwargs)
        Baustelle::CloudFormation::InternalDNS.cname(template, @internal_dns,
                                                     name: name, target: target,
                                                     **kwargs)
      end
    end
  end
end
