require 'yaml'
require 'deep_merge'

module Platform
  module Config
    extend self

    def read(filepath)
      YAML.load(File.read(filepath))
    end

    def for_environment(config, environment)
      if override = config.fetch('environments', {})[environment]
        override.deep_merge(config).reject { |k,_| k == 'environments' }
      else
        config
      end
    end
  end
end
