require 'tempfile'

module Baustelle
  module Jenkins
    class JobTemplate
      def initialize(template, working_dir,  options={})
        @template = template
        @options = options
        @working_dir = working_dir
      end

      def render(prefix: '')
        groovy_template = Tempfile.open(['job', '.groovy'], groovy_scripts_dir)
        groovy_template.puts render_groovy
        groovy_template.close
        Dir.mktmpdir do |output_dir|
          Dir.chdir(job_dsl_dir) do
            path = File.join('jobs', File.basename(groovy_template.path))
            if(system "./gradlew -q xml -Psource=#{path} -PoutputDir=#{output_dir}")
            else
              raise Exception.new('Error during job DSL rendering')
            end

          end

          Dir[File.join(output_dir, "*.xml")].inject({}) do |result, filename|
            result[prefix + File.basename(filename, '.xml')] = File.read(filename)
            result
          end
        end
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
