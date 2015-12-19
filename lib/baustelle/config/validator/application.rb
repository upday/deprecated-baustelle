module Baustelle
  module Config
    module Validator
      class Application
        extend RSchema::DSL::Base

        def self.schema(full_config)
          {
            'git' => Hash,
            'stack' => String, # enum
            'scale' => {
              'min' => Fixnum,
              'max' => Fixnum
            },
            'instance_type' => String, #enum
            'config' => Hash,
            optional('systemtests') => either(String, Hash),
            optional('elb') => Hash,
            optional('maven') => Hash
          }
        end
      end
    end
  end
end
