require 'yaml'
require 'deep_merge'

module Baustelle
  module Config
    extend self

    def read(filepath)
      YAML.load(File.read(filepath))
    end

    def for_environment(config, environment)
      if override = config.fetch('environments', {})[environment]
        override.deep_merge(config.reject { |k,_| k == 'environments' })
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
  end
end
