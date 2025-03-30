# frozen_string_literal: true

require "json"
require "English"
require "uri"
require_relative "constants"
require_relative "server/client_connection"
require_relative "server/stdio_client_connection"

module MCP
  # A Server handles MCP requests from an MCP client using the App.
  class Server
    MAX_AWAITING_RESPONSES = 100

    attr_reader :app

    def initialize(app)
      @app = app
      @initialized = false
      @supported_protocol_versions = [Constants::PROTOCOL_VERSION]
      @client_capabilities = {}
      @request_id_counter = 0
      @awaiting_responses = {}
      @app.boot
    end

    def name
      @app.name
    end

    def version
      @app.version
    end

    def initialized?
      @initialized
    end

    # Serve a client via the given connection.
    # This method will block while the client is connected.
    # It's the caller's responsibility to create Threads or Fibers to handle multiple clients.
    # @param client_connection [ClientConnection] The connection to the client.
    def serve(client_connection)
      loop do
        next_message = client_connection.read_next_message
        break if next_message.nil? # Client closed the connection

        response = process_input(next_message)

        # Notifications don't return a response so don't send anything
        client_connection.send_message(response) if response

        # Check if we need to perform any pending actions
        pending_actions do |request|
          client_connection.send_message(request)
        end
      end
    end

    def list_tools
      @app.list_tools[:tools]
    end

    def call_tool(name, **args)
      @app.call_tool(name, **args).dig(:content, 0, :text)
    end

    def list_resources
      @app.list_resources[:resources]
    end

    def list_resource_templates
      @app.list_resource_templates[:resourceTemplates]
    end

    def read_resource(uri)
      @app.read_resource(uri).dig(:contents, 0, :text)
    end

    private

    def process_input(line)
      result = begin
        message = JSON.parse(line, symbolize_names: true)

        case message
        in {result: _, id: /^s/} then handle_response(message)
        in {method: _} then handle_request(message)
        else
          error_response(nil, Constants::ErrorCodes::INVALID_REQUEST, "Unknown message format #{message.inspect}")
        end
      rescue JSON::ParserError => e
        error_response(nil, Constants::ErrorCodes::PARSE_ERROR, "Invalid JSON: #{e.message}")
      rescue => e
        error_response(nil, Constants::ErrorCodes::INTERNAL_ERROR, e.message)
      end

      result = JSON.generate(result) if result
      result
    end

    def handle_request(request)
      allowed_methods = [
        Constants::RequestMethods::INITIALIZE,
        Constants::RequestMethods::INITIALIZED,
        Constants::RequestMethods::PING
      ]
      if !@initialized && !allowed_methods.include?(request[:method])
        return error_response(request[:id], Constants::ErrorCodes::NOT_INITIALIZED, "Server not initialized")
      end

      case request[:method]
      when Constants::RequestMethods::INITIALIZE then handle_initialize(request)
      when Constants::RequestMethods::INITIALIZED then handle_initialized(request)
      when Constants::RequestMethods::PING then handle_ping(request)
      when Constants::RequestMethods::TOOLS_LIST then handle_list_tools(request)
      when Constants::RequestMethods::TOOLS_CALL then handle_call_tool(request)
      when Constants::RequestMethods::RESOURCES_LIST then handle_list_resources(request)
      when Constants::RequestMethods::RESOURCES_READ then handle_read_resource(request)
      when Constants::RequestMethods::RESOURCES_TEMPLATES_LIST then handle_list_resources_templates(request)
      when Constants::RequestMethods::ROOTS_LIST_CHANGED then handle_roots_list_changed_notification(request)
      else
        error_response(request[:id], Constants::ErrorCodes::METHOD_NOT_FOUND, "Unknown method: #{request[:method]}")
      end
    end

    def handle_initialize(request)
      return error_response(request[:id], Constants::ErrorCodes::ALREADY_INITIALIZED, "Server already initialized") if @initialized

      client_version = request.dig(:params, :protocolVersion)
      unless @supported_protocol_versions.include?(client_version)
        return error_response(
          request[:id],
          Constants::ErrorCodes::INVALID_PARAMS,
          "Unsupported protocol version",
          {
            supported: @supported_protocol_versions,
            requested: client_version
          }
        )
      end

      @client_params = request[:params] || {}
      @app.initialize_client(@client_params)
      @client_capabilities = @client_params[:capabilities] || {}
      @should_request_roots = @client_capabilities.dig(:roots, :listChanged) && roots_handler?

      {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: request[:id],
        result: {
          protocolVersion: Constants::PROTOCOL_VERSION,
          capabilities: {
            resources: {
              subscribe: false,
              listChanged: false
            },
            tools: {
              listChanged: false
            }
          },
          serverInfo: {
            name: @app.name,
            version: @app.version
          }
        }
      }
    end

    def handle_initialized(request)
      return error_response(request[:id], Constants::ErrorCodes::ALREADY_INITIALIZED, "Server already initialized") if @initialized

      @app.client_initialized(@client_params)
      @initialized = true
      nil # 通知に対しては応答を返さない (No response for notifications)
    end

    def handle_list_tools(request)
      cursor = request.dig(:params, :cursor)
      result = @app.list_tools(cursor: cursor)
      success_response(request[:id], result)
    end

    def handle_call_tool(request)
      name = request.dig(:params, :name)
      arguments = request.dig(:params, :arguments)
      begin
        result = @app.call_tool(name, **arguments.transform_keys(&:to_sym))
        if result[:isError]
          error_response(request[:id], Constants::ErrorCodes::INVALID_REQUEST, result[:content].first[:text])
        else
          success_response(request[:id], result)
        end
      rescue ArgumentError => e
        error_response(request[:id], Constants::ErrorCodes::INVALID_REQUEST, e.message)
      end
    end

    def handle_list_resources(request)
      cursor = request.dig(:params, :cursor)
      result = @app.list_resources(cursor:)
      success_response(request[:id], result)
    end

    def handle_list_resources_templates(request)
      cursor = request.dig(:params, :cursor)
      result = @app.list_resource_templates(cursor:)
      success_response(request[:id], result)
    end

    def handle_read_resource(request)
      uri = request.dig(:params, :uri)
      result = @app.read_resource(uri)

      if result
        success_response(request[:id], result)
      else
        error_response(request[:id], Constants::ErrorCodes::INVALID_REQUEST, "Resource not found", {uri: uri})
      end
    end

    def handle_ping(request)
      success_response(request[:id], {})
    end

    def handle_response(message)
      id = message[:id]
      handler = @awaiting_responses.delete(id)

      case handler
      when Constants::RequestMethods::ROOTS_LIST then handle_roots_list_response(message)
      else
        return error_response(id, Constants::ErrorCodes::METHOD_NOT_FOUND, "Unknown response: #{message.inspect}")
      end

      nil # No response needed back to client
    end

    def pending_actions(&)
      if @should_request_roots
        @should_request_roots = false
        request = server_request(Constants::RequestMethods::ROOTS_LIST)
        yield JSON.generate(request)
      end
    end

    def roots_handler?
      @app.respond_to?(:roots_handler) && @app.roots_handler
    end

    def handle_roots_list_changed_notification(_message)
      return nil unless roots_handler?

      @should_request_roots = false
      server_request(Constants::RequestMethods::ROOTS_LIST)
    end

    def handle_roots_list_response(response)
      return nil unless roots_handler?

      roots = response.dig(:result, :roots)
      @app.root_changed(roots)
      nil
    end

    def next_request_id
      @request_id_counter += 1
      "s#{@request_id_counter}"
    end

    def server_request(method)
      # ensure we don't accumulate unlimited pending requests
      if @awaiting_responses.size > MAX_AWAITING_RESPONSES
        @awaiting_responses.shift
      end

      id = next_request_id
      @awaiting_responses[id] = method

      {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: id,
        method: method
      }
    end

    def success_response(id, result)
      {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: id,
        result: result
      }
    end

    def error_response(id, code, message, data = nil)
      response = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: id,
        error: {
          code: code,
          message: message
        }
      }
      response[:error][:data] = data if data
      response
    end
  end
end
