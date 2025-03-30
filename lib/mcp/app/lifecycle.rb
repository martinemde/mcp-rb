# frozen_string_literal: true

module MCP
  class App
    # Lifecycle events for MCP apps
    module Lifecycle
      def self.included(base)
        base.extend(ClassMethods)
        attr_accessor :boot_hooks, :initialize_client_hooks, :client_initialized_hooks
      end

      module ClassMethods
        def boot(&block)
          @boot_hooks ||= []
          @boot_hooks << block
        end

        def initialize_client(&block)
          @initialize_client_hooks ||= []
          @initialize_client_hooks << block
        end

        def client_initialized(&block)
          @client_initialized_hooks ||= []
          @client_initialized_hooks << block
        end
      end

      def boot_hooks
        self.class.boot_hooks
      end

      def initialize_client_hooks
        self.class.initialize_client_hooks
      end

      def client_initialized_hooks
        self.class.client_initialized_hooks
      end

      def boot
        boot_hooks&.each(&:call)
      end

      def initialize_client(params)
        initialize_client_hooks&.each do |hook|
          hook.call(params)
        end
      end

      def client_initialized(params)
        client_initialized_hooks&.each do |hook|
          hook.call(params)
        end
      end

      # def before_hooks
      #   self.class.before_hooks
      # end

      # def after_hooks
      #   self.class.after_hooks
      # end

      # def run_before_hooks(event, *args)
      #   before_hooks[event]&.each do |hook|
      #     hook.call(*args)
      #   end
      # end

      # def run_after_hooks(event, *args)
      #   after_hooks[event]&.each do |hook|
      #     hook.call(*args)
      #   end
      # end
    end
  end
end
