# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class DelegatorTest < MCPTest::TestCase
    def test_tool_registration
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.tool("test_tool") do
        description "A test tool"
        argument :value, String, required: true, description: "Test value"
        call { |args| args[:value].to_s }
      end

      tools = server.instance_variable_get(:@app).list_tools[:tools]

      assert_equal 1, tools.size
      assert_equal "test_tool", tools.first[:name]
      assert_equal "A test tool", tools.first[:description]
    end

    def test_resource_registration
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.resource("test_resource") do
        name "test_resource"
        description "A test resource"
        call { "test content" }
      end

      resources = server.instance_variable_get(:@app).list_resources[:resources]

      assert_equal 1, resources.size
      assert_equal "test_resource", resources.first[:name]
      assert_equal "A test resource", resources.first[:description]
    end

    def test_tool_block_execution
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.tool("echo") do
        description "Echo a message"
        argument :message, String, required: true, description: "Message to echo"
        call { |args| args[:message] }
      end

      result = server.instance_variable_get(:@app).call_tool("echo", message: "hello").dig(:content, 0, :text)

      assert_equal "hello", result
    end

    def test_resource_block_execution
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.resource("content") do
        name "content"
        call { "test content" }
      end

      result = server.instance_variable_get(:@app).read_resource("content").dig(:contents, 0, :text)

      assert_equal "test content", result
    end

    def test_tool_registration_with_invalid_name
      server = Server.new(name: "test_server")
      initialize_server(server)

      assert_raises(ArgumentError) { server.tool(nil) { "test" } }
      assert_raises(ArgumentError) { server.tool("") { "test" } }
    end

    def test_resource_registration_with_invalid_name
      server = Server.new(name: "test_server")
      initialize_server(server)

      assert_raises(ArgumentError) { server.resource(nil) { "test" } }
    end
  end
end
