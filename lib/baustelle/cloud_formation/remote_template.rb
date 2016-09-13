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

      def call(template)
        file.put(body: template.to_json)
        main_temlate_url = file.public_url
        template.childs.each do |child|
          file(child.name).put(child.to_json)
        end
        yield main_temlate_url
      ensure
        @bucket.clear!
      end

      private

      def file(name: SecureRandom.uuid)
        @file ||= @bucket.object(name + ".json")
      end
    end
  end
end
