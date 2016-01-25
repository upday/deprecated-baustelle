module Baustelle
  module StackTemplate::Graph
    extend self

    StackConfig = Struct.new(:region, :stack_name)

    def call(config, region:, stack_name:)
      stack_config = StackConfig.new(region, stack_name)

      {
        graphs: Baustelle::Config.for_every_environment(config) do |environment, env_config|
          {
            directed: true,
            type: "BaustelleEnvironment",
            label: environment,
            nodes: nodes(env_config, stack_config),
            edges: edges(env_config.fetch('applications', {}))
          }
        end.values
      }
    end

    private

    def nodes(config, stack_config)
      backends(config, stack_config) + applications(config, stack_config)
    end

    def backends(config, _)
      config.fetch('backends', {}).flat_map do |type, list|
        list.flat_map do |name, _|
          {
            id: "backend:#{type}:#{name}",
            type: type,
            label: "#{type}: #{name}",
            metadata: {}
          }
        end
      end
    end

    def applications(config, stack_config)
      config.fetch('applications', {}).
        reject { |_, app_config| app_config.fetch('disabled', false) }.
        map do |app_name, app_config|
        app_config = Baustelle::Config.app_config(config, app_name)
        {
          id: "application:#{app_name}",
          type: "application",
          label: app_name,
          metadata: {}
        }
      end
    end

    def edges(applications)
      applications.
        reject { |_, app_config| app_config.fetch('disabled', false) }.
        flat_map do |app_name, app_config|
        app_config.fetch('config', {}).flat_map do |_, value|
          case value
          when Baustelle::CloudFormation::EBEnvironment::BACKEND_REGEX
            {
              "relation": "edge relationship",
              source: "application:#{app_name}",
              target: "backend:#{$~[:type]}:#{$~[:name]}",
              directed: false,
              metadata: {}
            }
          when Baustelle::CloudFormation::EBEnvironment::APPLICATION_REF_REGEX
            {
              "relation": "edge relationship",
              source: "application:#{app_name}",
              target: "application:#{$~[:name]}",
              directed: true,
              metadata: {}
            }
          end
        end.compact
      end
    end

  end
end
