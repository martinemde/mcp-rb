# frozen_string_literal: true

require_relative "../../test_helper"

module MCP
  class App
    class ToolTest < MCPTest::TestCase
      def setup
        @app = App.new
      end

      def test_register_and_list_tools
        @app.register_tool("test_tool", description: "A test tool") { |args| args.to_s }
        result = @app.list_tools
        tools = result[:tools]

        assert_equal 1, tools.length
        assert_equal "test_tool", tools.first[:name]
        assert_equal "A test tool", tools.first[:description]
      end

      def test_tools_pagination
        10.times do |i|
          @app.register_tool("tool#{i}") { |args| args.to_s }
        end

        # First page
        result = @app.list_tools(page_size: 5)
        assert_equal 5, result[:tools].length
        assert_equal "tool0", result[:tools].first[:name]
        assert_equal "tool4", result[:tools].last[:name]

        # Second page
        result = @app.list_tools(page_size: 5, cursor: "5")
        assert_equal 5, result[:tools].length
        assert_equal "tool5", result[:tools].first[:name]
        assert_equal "tool9", result[:tools].last[:name]
      end

      def test_call_tool
        @app.register_tool("echo") { |args| args[:message] }
        result = @app.call_tool("echo", message: "hello")
        assert_equal({
          content: [{type: "text", text: "hello"}],
          isError: false
        }, result)

        error = assert_raises(ArgumentError) { @app.call_tool("non_existent") }
        assert_match(/Tool not found/, error.message)
      end

      def test_invalid_tool_registration
        error = assert_raises(ArgumentError) { @app.register_tool(nil) { "test" } }
        assert_match(/Tool name cannot be nil or empty/, error.message)

        error = assert_raises(ArgumentError) { @app.register_tool("") { "test" } }
        assert_match(/Tool name cannot be nil or empty/, error.message)

        error = assert_raises(ArgumentError) { @app.register_tool("test") }
        assert_match(/Block must be provided/, error.message)
      end
    end
  end
end
