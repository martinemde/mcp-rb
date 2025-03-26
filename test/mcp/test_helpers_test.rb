# frozen_string_literal: true

require_relative "../test_helper"

module MCPTest
  class TestHelpersTest < TestCase
    class AppWithRootHandler < MCP::App
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

    def test_client_server_pattern
      app = AppWithRootHandler.new
      test_server = spawn_test_server(app)
      client = test_client(roots: [
        { uri: "file:///test/path1", name: "Test Root 1" },
        { uri: "file:///test/path2", name: "Test Root 2" }
      ])

      # Before connection, app hasn't received roots
      refute app.roots_called

      # Connect client to server (includes initialization)
      client.connect(test_server)

      # After connection, app should have received roots
      assert app.roots_called
      assert_equal [
        { uri: "file:///test/path1", name: "Test Root 1" },
        { uri: "file:///test/path2", name: "Test Root 2" }
      ], app.last_received_roots

      # Reset the roots_called flag
      app.roots_called = false

      # Change the roots and verify app receives them
      client.change_roots_list([
        { uri: "file:///test/path3", name: "New Root" }
      ])

      # App should have received the new roots
      assert app.roots_called
      assert_equal [
        { uri: "file:///test/path3", name: "New Root" }
      ], app.last_received_roots
    end
  end
end
