require 'json'

module Baustelle
  module Commands
    module Wait
      extend self

      def call(region:, name:)
        Aws.config[:region] = region
        until (Baustelle::CloudFormation.get_stack_status(name) ||
               "DELETE_COMPLETE") =~ /.*_(COMPLETE|FAILED)/
          sleep 5
        end
      end
    end
  end
end
