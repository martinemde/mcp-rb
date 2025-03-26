module MCPTest
  # Helpers for testing MCP server and client interactions
  # These helpers make it easier to test the interaction between server and client
  # using a clean, declarative pattern.
  module Helpers
    # TestClient provides a client implementation for testing MCP server interactions.
    # It handles the fiber-based communication pattern and provides a clean API for
    # common operations like connecting to a server, sending requests, and handling responses.
    #
    # Example usage:
    #   app = MyMCPApp.new
    #   test_server = spawn_test_server(app)
    #   client = test_client(roots: [{ uri: "file:///path", name: "Root" }])
    #   client.connect(test_server)
    #   # Make assertions about the app state
    class TestClient
      include MCP::Server::ClientConnection

      # Initialize a new TestClient
      # @param options [Hash] options for the client
      # @option options [Array<Hash>] :roots an array of root objects with uri and name
      def initialize(options = {})
        @pending_messages = []
        @server_messages = []
        @roots = options[:roots] || []
        @server_fiber = nil
        @next_id = 0
      end

      # -- Connection Management --

      # Connect to a server and perform initialization handshake
      # @param server [Fiber] the server fiber (from spawn_test_server)
      # @return [Hash] the initialize response
      def connect(server)
        connect_fiber(server)
        response = send_initialize
        send_notification(method: MCP::Constants::RequestMethods::INITIALIZED)
        process_server_messages
        response
      end

      # Connect to a server fiber without performing initialization
      # Use this when you want to test behavior before initialization
      # @param server [Fiber] the server fiber (from spawn_test_server)
      def connect_fiber(server)
        @server_fiber = server
        @server_fiber.resume(self)
      end

      # -- Server API Methods --

      # Send a ping request to test server connectivity
      # @return [Hash] the response
      def send_ping
        send_request(method: MCP::Constants::RequestMethods::PING)
      end

      # List available tools from the server
      # @return [Hash] the response containing available tools
      def list_tools
        send_request(method: MCP::Constants::RequestMethods::TOOLS_LIST)
      end

      # Call a specific tool with parameters
      # @param name [String] the name of the tool to call
      # @param params [Hash] parameters to pass to the tool
      # @return [Hash] the response from the tool
      def call_tool(name, params)
        send_request(
          method: MCP::Constants::RequestMethods::TOOLS_CALL,
          params: { name: name, params: params }
        )
      end

      # List available resources
      # @param cursor [String, nil] optional cursor for pagination
      # @return [Hash] the response containing resources
      def list_resources(cursor: nil)
        params = {}
        params[:cursor] = cursor if cursor

        send_request(
          method: MCP::Constants::RequestMethods::RESOURCES_LIST,
          params: params
        )
      end

      # Read a specific resource
      # @param name [String] the name of the resource to read
      # @return [Hash] the response containing the resource content
      def read_resource(name)
        send_request(
          method: MCP::Constants::RequestMethods::RESOURCES_READ,
          params: { name: name }
        )
      end

      # -- Roots Management --

      # Change the client's roots list and notify the server
      # @param new_roots [Array<Hash>] the new roots to set
      # @raise [RuntimeError] if roots support was not declared at initialization
      def change_roots_list(new_roots)
        raise "TestClient did not declare support for roots at initialization" unless @roots

        @roots = new_roots
        send_notification(
          method: MCP::Constants::RequestMethods::ROOTS_LIST_CHANGED
        )
        process_server_messages
      end

      # -- Message Handling --

      # Process any pending messages from the server
      # This handles common message types automatically
      def process_server_messages
        while message = @server_messages.shift
          parsed = parse_message(message)
          handle_message(parsed) if parsed
        end
      end

      # Handle the next server message, raising an error if none is available
      # @yield [message] the parsed message if a block is given
      # @return [Hash] the parsed message
      # @raise [RuntimeError] if no message is available
      def handle_next_message!
        resume_server
        message = @server_messages.shift
        raise "Expected server message but got none" unless message

        parsed = parse_message(message)
        yield parsed if block_given?
        parsed
      end

      # Send a raw message (for testing invalid messages)
      # @param message [String] the raw message to send
      # @return [Hash, nil] the response, if any
      def send_raw_message(message)
        @pending_messages << message
        resume_server

        response = @server_messages.shift
        return nil unless response

        parse_message(response)
      end

      # Send initialize with custom protocol version
      # @param protocol_version [String] the protocol version to use
      # @return [Hash] the response
      def send_initialize(protocol_version = MCP::Constants::PROTOCOL_VERSION)
        capabilities = {}
        capabilities[:roots] = { listChanged: true } if @roots.any?

        send_request(
          method: MCP::Constants::RequestMethods::INITIALIZE,
          params: {
            protocolVersion: protocol_version,
            capabilities: capabilities
          }
        )
      end

      # -- ClientConnection Interface --

      # Read the next message from the client queue
      # @return [String] the next message
      def read_next_message
        Fiber.yield while @pending_messages.empty?
        message = @pending_messages.shift
        log_message("CLIENT -> SERVER", message)
        message
      end

      # Send a message to the client
      # @param message [String] the message to send
      def send_message(message)
        log_message("SERVER -> CLIENT", message)
        @server_messages << message
      end

      private

      # -- Private Message Handling --

      def handle_message(parsed)
        case parsed[:method]
        when MCP::Constants::RequestMethods::ROOTS_LIST
          handle_roots_list_request(parsed)
        end
      end

      def handle_roots_list_request(message)
        send_request(
          id: message[:id],
          result: { roots: @roots }
        )
      end

      # -- Private Utility Methods --

      def send_request(values)
        message = build_message(values)
        @pending_messages << message
        resume_server

        response = @server_messages.shift
        return nil unless response

        parse_message(response)
      end

      def send_notification(values)
        message = build_message(values)
        @pending_messages << message
        resume_server
        process_server_messages
        nil
      end

      def build_message(values)
        message = { jsonrpc: MCP::Constants::JSON_RPC_VERSION }.merge(values)
        message[:id] = values[:id] || (@next_id += 1) unless values.key?(:result)
        message.is_a?(String) ? message : JSON.generate(message)
      end

      def parse_message(message)
        return message if message.is_a?(Hash)
        JSON.parse(message, symbolize_names: true)
      rescue JSON::ParserError
        message
      end

      def resume_server
        @server_fiber.resume
      end

      def log_message(direction, message)
        puts "#{direction}: #{message}" if ENV["DEBUG"]
      end
    end

    # Create a server Fiber for testing
    # @param app [MCP::App] the app to serve
    # @return [Fiber] a fiber that serves the app
    def spawn_test_server(app)
      server = MCP::Server.new(app)
      Fiber.new do |client|
        server.serve(client)
      end
    end

    # Create a test client with the given options
    # @param options [Hash] options to pass to the TestClient constructor
    # @return [TestClient] a new TestClient instance
    def test_client(options = {})
      TestClient.new(options)
    end

    # Configure an app with name and version for testing
    # @param name [String] the app name
    # @param version [String] the app version
    # @return [MCP::App] the configured app
    def configure_test_app(name: "test_server", version: "1.0.0")
      MCP::App.name name
      MCP::App.version version
      MCP::App.new
    end


    # Create a connected test client
    # @param app [MCP::App] the app to serve
    # @param client_options [Hash] options for the test client
    # @return [TestClient] the connected client
    def create_connected_test_client(app, **client_options)
      test_server = spawn_test_server(app)
      client = test_client(**client_options)
      client.connect(test_server)
      client
    end

    # Create a connected test client and return the initialization response
    # @param app [MCP::App] the app to serve
    # @param client_options [Hash] options for the test client
    # @return [Hash] the initialization response
    def initialization_response(app, **client_options)
      test_server = spawn_test_server(app)
      client = test_client(**client_options)
      client.connect(test_server)
    end

    # Create a connected test client without performing initialization
    # @param app [MCP::App] the app to serve
    # @param client_options [Hash] options for the test client
    # @return [TestClient] the connected client
    def create_uninitialized_test_client(app, **client_options)
      test_server = spawn_test_server(app)
      client = test_client(**client_options)
      client.connect_fiber(test_server)
      client
    end
  end
end
