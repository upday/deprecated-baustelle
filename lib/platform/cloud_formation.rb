require 'aws-sdk'
module Platform
  module CloudFormation
    extend self

    def build_template(config, name:)
      template = Template.new.tap do |template|
        vpc = VPC.apply(template, vpc_name: name,
                        cdir_block: config.fetch('vpc').fetch('cidr'),
                        subnets: config.fetch('vpc').fetch('subnets'))


        applications = Platform::Config.applications(config).map do |app_name|
          OpenStruct.new(name: app_name,
                         ref: Application.apply(template, app_name))
        end

        Platform::Config.environments(config).each do |env_name|
          env_config = Platform::Config.for_environment(config, env_name)
          applications.each do |app|
            EBEnvironment.apply(template,
                                env_name: env_name,
                                app_ref: app.ref,
                                app_name: app.name,
                                vpc: vpc,
                                app_config: Platform::Config.app_config(env_config, app.name),
                                stack_configurations: env_config.fetch('stacks'))
          end
        end
      end
      JSON.pretty_generate(template.as_json)
    end

    def create_stack(name, json)
      result = cfn_client.create_stack(stack_name: name,
                                       template_body: json,
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

    def update_stack(name, json)
      result = cfn_client.update_stack(stack_name: name,
                                       template_body: json,
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

    private

    def cfn_client
      Aws::CloudFormation::Client.new(validate_params: false)
    end
  end
end
