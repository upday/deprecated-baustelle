require 'aws-sdk'
module Baustelle
  module CloudFormation
    extend self

    def build_template(config, name:)
      template = Template.new.tap do |template|

        # Prepare VPC
        vpc = VPC.apply(template, vpc_name: name,
                        cdir_block: config.fetch('vpc').fetch('cidr'),
                        subnets: config.fetch('vpc').fetch('subnets'))


        # Create Beanstalk applications
        applications = Baustelle::Config.applications(config).map do |app_name|
          canonical_app_name = [name, app_name].join('_')
          OpenStruct.new(name: app_name,
                         canonical_name: canonical_app_name,
                         ref: Application.apply(template, canonical_app_name))
        end

        # For every environemnt
        Baustelle::Config.environments(config).each do |env_name|
          env_config = Baustelle::Config.for_environment(config, env_name)

          # Create backends
          (env_config['backends'] || {}).each do |type, backends|
            backend_klass = Baustelle::Backend.const_get(type)

            backends.each do |name, options|
              backend_name = [env_name, name].join('_')

              backend = backend_klass.new(backend_name, options, vpc: vpc)
              backend.build(template)
            end
          end

          # Create applications
          applications.each do |app|
            EBEnvironment.apply(template,
                                stack_name: name,
                                env_name: env_name,
                                app_ref: app.ref,
                                app_name: app.name,
                                vpc: vpc,
                                app_config: Baustelle::Config.app_config(env_config, app.name),
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
