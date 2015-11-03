require 'aws-sdk'
module Baustelle
  module CloudFormation
    extend self

    def create_stack(name, url)
      result = cfn_client.create_stack(stack_name: name,
                                       template_url: url,
                                       parameters: [],
                                       tags: [],
                                       capabilities: ["CAPABILITY_IAM"])
      if result.successful?
        result.stack_id
      end
    rescue Aws::CloudFormation::Errors::ServiceError => e
      $stderr.puts "Failed to create stack: #{e}"
      false
    end

    def update_stack(name, url)
      result = cfn_client.update_stack(stack_name: name,
                                       template_url: url,
                                       parameters: [],
                                       capabilities: ["CAPABILITY_IAM"])
      result.successful?
    rescue Aws::CloudFormation::Errors::ServiceError => e
      return true if e.message =~ /No updates are to be performed/
      $stderr.puts "Failed to update stack: #{e}"
      false
    end

    def delete_stack(name)
      cfn_client.delete_stack(stack_name: name).successful?
    rescue Aws::CloudFormation::Errors::ServiceError => e
      $stderr.puts "Failed to delete stack: #{e}"
      false
    end

    def get_stack_status(name)
      result = cfn_client.describe_stacks(stack_name: name)
      if stack = result.stacks.first
        stack.stack_status
      end
    rescue Aws::CloudFormation::Errors::ServiceError => e
      nil
    end

    private

    def cfn_client
      Aws::CloudFormation::Client.new(validate_params: false)
    end
  end
end
