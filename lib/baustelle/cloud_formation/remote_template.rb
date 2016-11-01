require 'aws-sdk'
require 'securerandom'
require 'baustelle/workspace_bucket'

module Baustelle
  module CloudFormation
    class RemoteTemplate
      attr_reader :bucket

      def initialize(stack_name,
                     region:,
                     bucket: Baustelle::WorkspaceBucket.new(region: region).call)
        @bucket = bucket
        @region = region
        @stack_name = stack_name
      end

      def call(template)
        stack_template = template.build(@stack_name, @region, @bucket.url)
        main_template_s3object = file
        main_template_s3object.put(body: stack_template.to_json)
        main_temlate_url = main_template_s3object.public_url
        stack_template.childs.each do |child_name, child_template|
          child_template_s3object = file(child_name)
          child_template_s3object.put(body: child_template.to_json)
        end
        yield main_temlate_url
      end

      def clear_bucket
        @bucket.clear!
      end

      private

      def file(name = SecureRandom.uuid)
        @bucket.object(name + ".json")
      end
    end
  end
end
