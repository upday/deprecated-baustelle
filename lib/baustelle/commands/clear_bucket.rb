module Baustelle
  module Commands
    module ClearBucket
      extend self

      def call(region:, name:)
        Aws.config[:region] = region
        remote_template = Baustelle::CloudFormation::RemoteTemplate.new(name, region: region)
        remote_template.clear_bucket
        puts "Cleared S3 bucket"
      end
    end
  end
end
