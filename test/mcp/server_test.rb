# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class ServerTest < MCPTest::TestCase
    def test_server_initialization
      server = Server.new(name: "test_server")
      assert_equal "test_server", server.name
      assert_equal "0.1.0", server.version
      refute server.initialized
    end

    def test_initialize_request
      server = Server.new(name: "test_server")
      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: MCP::Constants::PROTOCOL_VERSION,
          capabilities: {},
          clientInfo: {
            name: "test_client",
            version: "1.0.0"
          }
        },
        id: 1
      }

      response = server.send(:handle_request, request)
      assert_equal MCP::Constants::JSON_RPC_VERSION, response[:jsonrpc]
      assert_equal 1, response[:id]
      assert_equal MCP::Constants::PROTOCOL_VERSION, response[:result][:protocolVersion]
      assert_equal false, response[:result][:capabilities][:tools][:listChanged]
    end

    def test_initialize_with_unsupported_version
      server = Server.new(name: "test_server")
      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: "1999-01-01",
          capabilities: {}
        },
        id: 1
      }

      response = server.send(:handle_request, request)
      assert_equal "2.0", response[:jsonrpc]
      assert_equal 1, response[:id]
      assert response[:error]
      assert_equal "Unsupported protocol version", response[:error][:message]
    end

    def test_initialized_notification
      server = Server.new(name: "test_server")

      # First initialize
      init_request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: MCP::Constants::PROTOCOL_VERSION,
          capabilities: {}
        },
        id: 1
      }
      server.send(:handle_request, init_request)

      # Then send initialized notification
      init_notification = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::INITIALIZED,
        id: 2
      }
      response = server.send(:handle_request, init_notification)

      assert_nil response
    end

    def test_request_before_initialization
      server = Server.new(name: "test_server")
      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::TOOLS_LIST,
        id: 1
      }

      response = server.send(:handle_request, request)
      assert_equal(-32_002, response[:error][:code])
      assert_equal "Server not initialized", response[:error][:message]
    end

    def test_handle_call_tool
      server = Server.new(name: "test_server")
      initialize_server(server)

      # Register and call the tool
      server.tool("echo") do
        description "Echo a message"
        argument :message, String, required: true, description: "Message to echo"
        call { |args| args[:message] }
      end

      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: 1,
        method: MCP::Constants::RequestMethods::TOOLS_CALL,
        params: {
          name: "echo",
          arguments: {message: "hello"}
        }
      }

      response = server.send(:handle_request, request)

      assert_equal "2.0", response[:jsonrpc]
      assert_equal 1, response[:id]
      assert_match(/hello/, response[:result][:content].first[:text])
      refute response[:result][:isError]

      # Test error handling
      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: 2,
        method: MCP::Constants::RequestMethods::TOOLS_CALL,
        params: {
          name: "non_existent_tool",
          arguments: {}
        }
      }

      response = server.send(:handle_request, request)
      assert_equal "2.0", response[:jsonrpc]
      assert_equal 2, response[:id]
      assert response[:error]
      assert_match(/Tool not found/, response[:error][:message])
    end

    def test_handle_ping
      server = Server.new(name: "test_server")

      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::PING,
        id: 1
      }

      response = server.send(:handle_request, request)
      assert_equal "2.0", response[:jsonrpc]
      assert_equal 1, response[:id]
      assert_equal({}, response[:result])
    end
  end

  class NewServerTest < MCPTest::TestCase
    def test_basic_server_info
      prepare_server(name: "special_test_server", version: "1.4.1")

      assert_equal "special_test_server", @server.name
      assert_equal "1.4.1", @server.version
    end

    def test_knows_if_initialized
      start_server

      refute @server.initialized?

      send_message(a_valid_initialize_request)
      send_message(a_valid_initialized_notification)

      assert @server.initialized?
    end

    def test_responds_with_server_info_on_initialize
      start_server(name: "special_test_server", version: "1.4.1")

      response = send_message(a_valid_initialize_request)

      expected = {
        name: "special_test_server",
        version: "1.4.1"
      }
      assert_equal expected, response[:result][:serverInfo]
    end

    def test_supports_tools_without_list_changed
      start_server

      response = send_message(a_valid_initialize_request)

      expected = { listChanged: false }
      assert_equal expected, response[:result][:capabilities][:tools]
    end

    def test_supports_resources_without_sub_capabilities
      start_server

      response = send_message(a_valid_initialize_request)

      expected = {
        subscribe: false,
        listChanged: false
      }
      assert_equal expected, response[:result][:capabilities][:resources]
    end

    def test_unsupported_protocol_version
      start_server

      request = json_rpc_message(
        method: Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: "1999-01-01",
          capabilities: {}
        },
      )
      response = send_message(request)

      assert response[:error]
      assert_equal Constants::ErrorCodes::INVALID_PARAMS, response[:error][:code]
      assert_equal "Unsupported protocol version", response[:error][:message]
    end

    private

    # Assumed to be run inside a Fiber
    class MockTransportAdapter
      def initialize
        @connected = false
        @pending_client_messages = []
        @pending_server_messages = []
      end

      # TransportAdapter interface methods

      def connect
        @connected = true
      end

      def read_next_message
        ensure_connected!

        Fiber.yield until @pending_client_messages.any?

        @pending_client_messages.shift
      end

      def send_message(message)
        ensure_connected!

        @pending_server_messages << message
      end

      # Test helper methods

      def <<(message)
        @pending_client_messages << message
      end

      def next_pending_server_message
        @pending_server_messages.shift
      end

      private

      def ensure_connected!
        raise "Not connected" unless @connected
      end
    end

    def start_server(...)
      prepare_server(...)
      @server_fiber = Fiber.new { @server.run }
      @server_fiber.resume
    end

    def prepare_server(name: "test_server", version: nil)
      @transport_adapter = MockTransportAdapter.new
      kwargs = {
        name: name,
        version: version,
        transport_adapter: @transport_adapter
      }.compact
      @server = NewServer.new(**kwargs)
      @next_id = 1
    end

    def send_message(message)
      @transport_adapter << message
      @server_fiber.resume
      next_pending_server_message
    end

    def next_pending_server_message
      result = @transport_adapter.next_pending_server_message
      result = JSON.parse(result, symbolize_names: true) if result
      result
    end

    def a_valid_initialize_request
      json_rpc_message(
        method: Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: Constants::PROTOCOL_VERSION,
          capabilities: {}
        }
      )
    end

    def a_valid_initialized_notification
      json_rpc_notification(
        method: Constants::RequestMethods::INITIALIZED
      )
    end

    def json_rpc_message(values)
      result = {
        jsonrpc: Constants::JSON_RPC_VERSION,
        id: @next_id,
        **values
      }.to_json

      @next_id += 1

      result
    end

    def json_rpc_notification(values)
      {
        jsonrpc: Constants::JSON_RPC_VERSION,
        **values
      }.to_json
    end
  end
end
