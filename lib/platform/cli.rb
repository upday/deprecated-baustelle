require 'thor'
require 'platform'

module Platform
  class CLI < Thor
    class_option "region", desc: 'region where to run commands in',
                 default: ENV.fetch('AWS_DEFAULT_REGION', 'us-east-1')
    class_option "name", desc: 'name of the platform stack', default: 'platform'


    desc "create", "Create the platform according to specification in the yml file"
    option "specification", desc: 'path to the specification file',
           default: 'platform.yml'
    def create
      Platform::Commands::Create.call(specification_file, region: region,
                                      name: name)
    end

    desc "update", "Update the platform according to specification in the yml file"
    option "specification", desc: 'path to the specification file',
           default: 'platform.yml'
    def update
      Platform::Commands::Update.call(specification_file, region: region,
                                      name: name)
    end


    desc "delete", "Deletes the platform"
    def delete
      Platform::Commands::Delete.call(name: name, region: region)
    end

    private

    def specification_file
      options.fetch("specification", "platform.yml")
    end

    def region
      options.fetch('region', ENV.fetch('AWS_DEFAULT_REGION', 'us-east-1'))
    end

    def name
      options.fetch('name', 'platform')
    end
  end
end
