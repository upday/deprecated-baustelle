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
        stack_template = template.build(@stack_name, @region, @bucket.name)
        file.put(body: stack_template.to_json)
        main_temlate_url = file.public_url
        stack_template.childs.each do |child_name, child_template|
          file("#{child_name}.json").put(child_template.to_json)
        end
        yield main_temlate_url
      ensure
        @bucket.clear!
      end

      private

      def file(name = SecureRandom.uuid)
        @file ||= @bucket.object(name + ".json")
      end
    end
  end
end
