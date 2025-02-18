# frozen_string_literal: true

require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require_relative "../lib/mcp"

module MCPTest
  class TestCase < Minitest::Test
    protected

    def initialize_server(server)
      init_request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: "initialize",
        params: {
          protocolVersion: MCP::Constants::PROTOCOL_VERSION,
          capabilities: {}
        },
        id: 1
      }
      server.send(:handle_request, init_request)

      init_notification = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: "notifications/initialized",
        id: 2
      }
      server.send(:handle_request, init_notification)
    end
  end
end
