# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class ServerRootsTest < MCPTest::TestCase
    class AppWithRootHandler < App
      def initialize
        super
        @roots_called = false
        @last_received_roots = nil
      end

      attr_accessor :roots_called, :last_received_roots

      roots do |roots_data|
        @roots_called = true
        @last_received_roots = roots_data
      end
    end

    class AppWithoutRootHandler < App
      # This app does not define a roots handler
    end

    def setup
      @app_with_handler = AppWithRootHandler.new
      @app_without_handler = AppWithoutRootHandler.new
    end

    def teardown
      App.reset!
    end

    def test_server_requests_roots_when_app_has_handler
      test_roots = [
        { uri: "file:///test/path1", name: "Test Root 1" },
        { uri: "file:///test/path2", name: "Test Root 2" }
      ]

      refute @app_with_handler.roots_called
      client, = create_connected_test_client(@app_with_handler, roots: test_roots)
      assert @app_with_handler.roots_called
      assert_equal test_roots, @app_with_handler.last_received_roots
    end

    def test_server_does_not_request_roots_when_app_has_no_handler
      client, = create_connected_test_client(@app_without_handler, roots: [{ uri: "file:///test/path1", name: "Test Root 1" }])
      # No assertion needed - if the server requests roots, the client will raise an error
      # since we're not expecting any messages after initialization
    end

    def test_server_handles_roots_list_response
      test_roots = [
        { uri: "file:///test/path1", name: "Test Root 1" },
        { uri: "file:///test/path2", name: "Test Root 2" }
      ]

      refute @app_with_handler.roots_called
      client, = create_connected_test_client(@app_with_handler, roots: test_roots)
      assert @app_with_handler.roots_called
      assert_equal test_roots, @app_with_handler.last_received_roots
    end

    def test_server_handles_roots_list_changed_notification
      initial_roots = [{ uri: "file:///test/path1", name: "Test Root 1" }]
      new_roots = [{ uri: "file:///test/path2", name: "New Root" }]

      client, = create_connected_test_client(@app_with_handler, roots: initial_roots)
      @app_with_handler.roots_called = false # Reset the flag

      # Change roots and verify the app receives them
      client.change_roots_list(new_roots)

      assert @app_with_handler.roots_called
      assert_equal new_roots, @app_with_handler.last_received_roots
    end
  end
end
