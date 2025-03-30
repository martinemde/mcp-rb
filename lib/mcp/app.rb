# frozen_string_literal: true

require_relative "app/lifecycle"
require_relative "app/resource"
require_relative "app/resource_template"
require_relative "app/tool"
require_relative "app/roots"

module MCP
  class App
    include Resource
    include ResourceTemplate
    include Tool
    include Roots
    include Lifecycle

    class << self
      def name(value = nil)
        return @name if value.nil?

        @name = value
      end

      def version(value = nil)
        return @version if value.nil?

        @version = value
      end

      def reset!
        super
        @name = nil
        @version = nil
        @tools = nil
        @resources = nil
        @resource_templates = nil
        @roots_handler = nil
      end
    end

    def settings
      self.class
    end

    def name
      settings.name
    end

    def version
      settings.version
    end
  end
end
