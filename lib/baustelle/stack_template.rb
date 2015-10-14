module Baustelle
  class StackTemplate
    def initialize(config)
      @config = config
    end

    def build(name, template: CloudFormation::Template.new)
      # Prepare VPC
      vpc = CloudFormation::VPC.apply(template, vpc_name: name,
                                      cdir_block: config.fetch('vpc').fetch('cidr'),
                                      subnets: config.fetch('vpc').fetch('subnets'))


      # Create Beanstalk applications
      applications = Baustelle::Config.applications(config).map do |app_name|
        canonical_app_name = [name, app_name].join('_')
        OpenStruct.new(name: app_name,
                       canonical_name: canonical_app_name,
                       ref: CloudFormation::Application.apply(template, canonical_app_name))
      end

      # For every environemnt
      Baustelle::Config.environments(config).each do |env_name|
        env_config = Baustelle::Config.for_environment(config, env_name)

        # Create backends

        environment_backends = Hash.new { |h,k| h[k] = {} }

        (env_config['backends'] || {}).inject(environment_backends) do |acc, (type, backends)|
          backend_klass = Baustelle::Backend.const_get(type)

          backends.each do |name, options|
            backend_name = [env_name, name].join('_')
            acc[type][name] = backend = backend_klass.new(backend_name, options, vpc: vpc)
            backend.build(template)
          end
        end

        # Create applications
        applications.each do |app|
          CloudFormation::EBEnvironment.apply(template,
                                              stack_name: name,
                                              env_name: env_name,
                                              app_ref: app.ref,
                                              app_name: app.name,
                                              vpc: vpc,
                                              app_config: Baustelle::Config.app_config(env_config, app.name),
                                              stack_configurations: env_config.fetch('stacks'),
                                              backends: environment_backends)
        end
      end
      template
    end

    private

    attr_reader :config
  end
end
