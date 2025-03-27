# frozen_string_literal: true

module MCP
  class App
    # Include this module in your app to add roots functionality
    module Roots
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def roots(&block)
          @roots_handler = block
        end

        def roots_handler
          @roots_handler
        end

        def reset!
          @roots_handler = nil
        end
      end

      def roots
        @roots ||= []
      end

      def roots_handler
        self.class.roots_handler
      end

      def roots_handler?
        !roots_handler.nil?
      end

      def root_changed(new_roots)
        @roots = new_roots
        # is this the right way to evaluate with the app context??
        instance_exec(new_roots, &roots_handler)
      end
    end
  end
end
