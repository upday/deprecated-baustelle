require 'json'

module Baustelle
  module Commands
    module Delete
      extend self

      def call(region:, name:)
        Aws.config[:region] = region
        Baustelle::CloudFormation.delete_stack(name) or exit(1)
        puts "Deleted stack #{name} in #{region}"
      end
    end
  end
end
