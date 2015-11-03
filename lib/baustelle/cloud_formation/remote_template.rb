require 'aws-sdk'
require 'securerandom'
require 'baustelle/workspace_bucket'

module Baustelle
  module CloudFormation
    class RemoteTemplate
      attr_reader :bucket

      def initialize(region:,
                     bucket: Baustelle::WorkspaceBucket.new(region: region).call)
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
