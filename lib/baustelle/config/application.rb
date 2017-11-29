module Baustelle
  module Config
    class Application

      attr_reader :raw

      def initialize(app_config)
        @raw = app_config
      end

      def config
        @raw.fetch('config', {})
      end

      def https?
        @raw.fetch('elb', {}).fetch('https', false)
      end

      def force_keep_http?
        @raw.fetch('elb', {}).fetch('keep_http_listener', false)
      end

      def dns_name
        @raw.fetch('dns', {})['name']
      end

      def disabled?
        @raw.fetch('disabled', false)
      end

      def elb
        @raw.fetch('elb', {})
      end

      def elb_visibility
        elb.fetch('visibility', 'public')
      end

      def healthcheck_path
        @raw.fetch('healthcheck_path', '/health')
      end

    end
  end
end
