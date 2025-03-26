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

      attr_reader :roots_called, :last_received_roots

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
      @mock_client_connection = MockClientConnection.new
    end

    def teardown
      App.reset!
    end

    def test_server_requests_roots_when_app_has_handler
      server = Server.new(@app_with_handler)

      # Start server fiber
      server_fiber = Fiber.new { server.serve(@mock_client_connection) }
      server_fiber.resume

      # Send initialize request with roots capability
      init_request = json_rpc_message(
        method: Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: Constants::PROTOCOL_VERSION,
          capabilities: {
            roots: {
              listChanged: true
            }
          }
        }
      )

      @mock_client_connection << init_request
      server_fiber.resume
      @mock_client_connection.next_pending_server_message # consume response

      # Send initialized notification
      init_notification = json_rpc_notification(
        method: Constants::RequestMethods::INITIALIZED
      )

      @mock_client_connection << init_notification
      server_fiber.resume

      # Server should have requested roots
      roots_request = @mock_client_connection.next_pending_server_message
      assert roots_request, "Server should have requested roots"

      parsed_request = JSON.parse(roots_request, symbolize_names: true)
      assert_equal Constants::RequestMethods::ROOTS_LIST, parsed_request[:method]
    end

    def test_server_does_not_request_roots_when_app_has_no_handler
      @app_without_handler = AppWithoutRootHandler.new
      server = Server.new(@app_without_handler)

      # Start server fiber
      server_fiber = Fiber.new { server.serve(@mock_client_connection) }
      server_fiber.resume

      # Send initialize request with roots capability
      init_request = json_rpc_message(
        method: Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: Constants::PROTOCOL_VERSION,
          capabilities: {
            roots: {
              listChanged: true
            }
          }
        }
      )

      @mock_client_connection << init_request
      server_fiber.resume
      @mock_client_connection.next_pending_server_message # consume response

      # Send initialized notification
      init_notification = json_rpc_notification(
        method: Constants::RequestMethods::INITIALIZED
      )

      @mock_client_connection << init_notification
      server_fiber.resume

      # Server should not have requested roots
      assert_nil @mock_client_connection.next_pending_server_message, "Server should not have requested roots"
    end

    def test_server_handles_roots_list_response
      server = Server.new(@app_with_handler)

      # Start server fiber
      server_fiber = Fiber.new { server.serve(@mock_client_connection) }
      server_fiber.resume

      # Initialize server with roots capability
      initialize_server(server_fiber, @mock_client_connection, with_roots: true)

      # Server should have requested roots
      roots_request = @mock_client_connection.next_pending_server_message
      assert roots_request, "Server should have requested roots"

      parsed_request = JSON.parse(roots_request, symbolize_names: true)

      # Send roots response
      test_roots = [
        { uri: "file:///test/path1", name: "Test Root 1" },
        { uri: "file:///test/path2", name: "Test Root 2" }
      ]

      roots_response = json_rpc_message(
        id: parsed_request[:id],
        result: {
          roots: test_roots
        }
      )

      @mock_client_connection << roots_response
      server_fiber.resume

      # App should have received the roots
      assert @app_with_handler.roots_called, "App's roots handler should have been called"
      assert_equal test_roots, @app_with_handler.last_received_roots
    end

    def test_server_handles_roots_list_changed_notification
      server = Server.new(@app_with_handler)

      # Start server fiber
      server_fiber = Fiber.new { server.serve(@mock_client_connection) }
      server_fiber.resume

      # Initialize server with roots capability
      initialize_server(server_fiber, @mock_client_connection, with_roots: true)

      # Consume initial roots request
      @mock_client_connection.next_pending_server_message

      # Send roots list changed notification
      notification = json_rpc_notification(
        method: Constants::RequestMethods::ROOTS_LIST_CHANGED
      )

      @mock_client_connection << notification
      server_fiber.resume

      # Server should request roots again
      roots_request = @mock_client_connection.next_pending_server_message
      assert roots_request, "Server should have requested roots after list changed notification"

      parsed_request = JSON.parse(roots_request, symbolize_names: true)
      assert_equal Constants::RequestMethods::ROOTS_LIST, parsed_request[:method]
    end

    private

    # Initialize a server with the given capabilities
    def initialize_server(server_fiber, client_connection, with_roots: false)
      capabilities = {}

      if with_roots
        capabilities[:roots] = { listChanged: true }
      end

      # Send initialize request
      init_request = json_rpc_message(
        method: Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: Constants::PROTOCOL_VERSION,
          capabilities: capabilities
        }
      )

      client_connection << init_request
      server_fiber.resume
      client_connection.next_pending_server_message # consume response

      # Send initialized notification
      init_notification = json_rpc_notification(
        method: Constants::RequestMethods::INITIALIZED
      )

      client_connection << init_notification
      server_fiber.resume
    end

    # Helper methods copied from ServerTest to keep test independent
    class MockClientConnection
      include Server::ClientConnection

      def initialize
        @pending_client_messages = []
        @pending_server_messages = []
      end

      # ClientConnection interface methods
      def read_next_message
        Fiber.yield while @pending_client_messages.empty?

        message = @pending_client_messages.shift
        puts "CLIENT -> SERVER: #{message}" if message
        message
      end

      def send_message(message)
        puts "SERVER -> CLIENT: #{message}"
        @pending_server_messages << message
      end

      # Test helper methods
      def <<(message)
        message_str = message.is_a?(String) ? message : JSON.generate(message)
        @pending_client_messages << message_str
      end

      def next_pending_server_message
        @pending_server_messages.shift
      end
    end

    def json_rpc_message(values)
      @next_id ||= 1
      {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: values[:id] || @next_id += 1
      }.merge(values)
    end

    def json_rpc_notification(values)
      {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION
      }.merge(values)
    end
  end
end
