require 'tempfile'
require 'tmpdir'

module Baustelle
  module Jenkins
    class JobTemplate
      def initialize(template, working_dir,  options={})
        @template = template
        @options = options
        @working_dir = working_dir
      end

      def render(prefix: '')
        dir_name = 'rendered_jobs'
        if !Dir::exist?(dir_name)
          Dir::mkdir('rendered_jobs', 0755)
        end
        groovy_template_path = Dir::new(dir_name)




         #Dir::Tmpname.make_tmpname(['job', '.groovy'],false).gsub('-','_')


        environment = @options[:eb_environment_name].split('-')[0]
        application = @options[:eb_application_name]
        job_type = @options[:job_type]
        groovy_template = File.open(File.join(groovy_template_path.path, "#{application}_#{environment}-#{job_type}.groovy").gsub('-','_'),'w')
        groovy_template.puts render_groovy
        groovy_template.close
      end

      def render_groovy
        ERB.new(@template).result(binding)
      end

      def method_missing(name)
        @options[name.to_sym] || @options[name]
      end

      private

      def include(partial_path)
        ERB.new(File.read(File.expand_path(File.join(@working_dir, partial_path + '.groovy')))).result(binding)
      end

      def job_dsl_dir
        File.expand_path(File.join(__FILE__, '../../../../ext/jenkins_dsl'))
      end

      def groovy_scripts_dir
        File.join(job_dsl_dir, "jobs")
      end
    end
  end
end
