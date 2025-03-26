# frozen_string_literal: true

require_relative "../../test_helper"

module MCP
  class App
    class RootsTest < MCPTest::TestCase
      class TestApp
        include MCP::App::Roots
      end

      def setup
        @app = TestApp.new
      end

      def teardown
        TestApp.reset!
      end

      def test_register_roots_handler
        # Initially no handler should be registered
        assert_nil @app.root_changed_handler

        # Register a handler
        called = false
        test_roots = nil

        TestApp.roots do |roots|
          called = true
          test_roots = roots
        end

        # Handler should be registered
        assert @app.root_changed_handler

        # Call the handler with test data
        test_data = [{ uri: "file:///test/path", name: "Test Root" }]
        @app.root_changed(test_data)

        # Verify handler was called with correct data
        assert called
        assert_equal test_data, test_roots
      end

      def test_default_roots
        # By default, roots should be an empty array
        assert_equal [], @app.roots
      end

      def test_reset_clears_handler
        # Register a handler
        TestApp.roots do |roots|
          # noop
        end

        # Verify handler is registered
        refute_nil @app.root_changed_handler

        # Reset the app
        TestApp.reset!

        # Handler should be cleared
        assert_nil @app.root_changed_handler
      end
    end
  end
end
