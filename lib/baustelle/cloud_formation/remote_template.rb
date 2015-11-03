require 'aws-sdk'
require 'securerandom'

module Baustelle
  module CloudFormation
    class RemoteTemplate
      attr_reader :bucket

      def initialize(bucket_name:, region:,
                     s3: Aws::S3::Resource.new(region: region),
                     bucket: s3.bucket(bucket_name))
        @bucket = bucket
      end

      def call(json)
        file.put(body: json)
        yield file.public_url
      ensure
        file.delete
      end

      private

      def file
        @file ||= @bucket.object(SecureRandom.uuid + ".json")
      end
    end
  end
end
