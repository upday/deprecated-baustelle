require 'yaml'
require 'active_support/core_ext/hash'
require 'baustelle/config/application'

module Baustelle
  module Config
    extend self

    def read(filepath)
      parse YAML.load(File.read(filepath))
    end

    # reads the specification from filepath and returns
    # the app_config for the given application in the given environment
    def read_app_config(filepath, app_name, env_name)
      config = Baustelle::Config.read(filepath)

      environments = Baustelle::Config.environments(config)
      if !environments.include?(env_name) 
        raise Thor::Error.new("No environment found with name #{env_name}")
      end

      env_config = Baustelle::Config.for_environment(config, env_name)
      Baustelle::Config.app_config(env_config, app_name)
    end

    def for_every_environment(config)
      environments(config).each do |environment|
        env_config = for_environment(config, environment)
        yield environment, for_environment(env_config, environment)
      end
    end

    def for_every_application(config)
      config['applications'].each do |app_name, app_config|
        yield app_name, Baustelle::Config::Application.new(app_config)
      end
    end

    def for_environment(config, environment)
      if override = config.fetch('environments', {})[environment]
        config.reject { |k,_| k == 'environments' }.deep_merge(override)
      else
        config
      end
    end

    def environments(config)
      config.fetch('environments').keys
    end

    def applications(config)
      config.fetch('applications').keys
    end

    def app_config(config, name)
      cfg = config.fetch('applications').fetch(name)
      Baustelle::Config::Application.new(cfg)
    end

    def parse(hash)
      hash.inject({}) do |parsed_hash, (key, value)|
        parsed_hash[key] = case value
                           when /include\(([^,]*),\s*(.*)\)$/
                             lookup(read($1), $2)
                           when /include\((.*)\)$/
                             read($1)
                           when Hash
                             parse(value)
                           else
                             value
                           end
        parsed_hash
      end
    end

    private

    def lookup(hash, path)
      path.split('.').inject(hash) do |value, key|
        value.fetch(key)
      end
    end
  end
end
