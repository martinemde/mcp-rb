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
          @root_changed_handler = block
        end

        def root_changed_handler
          @root_changed_handler
        end

        def reset!
          @root_changed_handler = nil
        end
      end

      def roots
        @roots ||= []
      end

      def root_changed_handler
        self.class.root_changed_handler
      end

      def root_changed(new_roots)
        @roots = new_roots
        # is this the right way to evaluate with the app context??
        instance_exec(new_roots, &root_changed_handler)
      end
    end
  end
end
