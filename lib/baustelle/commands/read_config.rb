require 'json'

module Baustelle
  module Commands
    module ReadConfig
      extend self

      def call(specification_file)
        config = Baustelle::Config.read(specification_file)

        output = Baustelle::Config.environments(config).inject({}) do |acc, env_name|
          acc[env_name] = Baustelle::Config.for_environment(config, env_name)
          acc
        end

        puts JSON.pretty_generate(output)
      end
    end
  end
end
