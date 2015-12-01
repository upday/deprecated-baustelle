require 'yaml'
require 'active_support/core_ext/hash'

module Baustelle
  module Config
    extend self

    def read(filepath)
      parse YAML.load(File.read(filepath))
    end

    def for_every_environment(config)
      environments(config).each do |environment|
        env_config = for_environment(config, environment)
        yield environment, for_environment(env_config, environment)
      end
    end

    def for_every_application(config)
      config['applications'].each do |app_name, app_config|
        yield app_name, app_config
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
      config.fetch('applications').fetch(name)
    end

    def parse(hash)
      hash.inject({}) do |parsed_hash, (key, value)|
        parsed_hash[key] = case value
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
  end
end
