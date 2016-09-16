require 'aws-sdk'
require 'securerandom'

module Baustelle
  class WorkspaceBucket
    def initialize(region:,
                   s3: Aws::S3::Client.new(region: region))
      @s3 = s3
    end

    def call
      bucket_object(find_bucket || create_bucket)
    end

    private

    def bucket_object(bucket)
      Aws::S3::Resource.new(client: @s3).
        bucket(bucket.name)
    end

    def find_bucket
      @s3.list_buckets.buckets.
        detect { |bucket| bucket.name =~ /^baustelle-workspace-.*/ }
    end

    def create_bucket
      @s3.create_bucket(bucket: generate_name)
    end

    def generate_name
      "baustelle-workspace-" + SecureRandom.uuid
    end

  end
end
