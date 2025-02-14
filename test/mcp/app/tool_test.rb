# frozen_string_literal: true

require_relative "../../test_helper"

module MCP
  class App
    class ToolTest < MCPTest::TestCase
      def setup
        @app = App.new
      end

      def test_tools_pagination
        10.times do |i|
          @app.register_tool("tool#{i}") do
            description "Tool #{i}"
            argument :value, String, required: true, description: "Value for tool #{i}"

            call do |args|
              "Tool #{i}: #{args[:value]}"
            end
          end
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

      def test_register_tool
        tool = @app.register_tool("greet") do
          description "Greet someone by name"
          argument :name, String, required: true, description: "Name to greet"

          call do |args|
            "Hello, #{args[:name]}!"
          end
        end

        assert_equal "greet", tool[:name]
        assert_equal "Greet someone by name", tool[:description]
        assert_equal(
          {
            type: :object,
            properties: {
              name: {
                type: :string,
                description: "Name to greet"
              }
            },
            required: [:name]
          },
          tool[:input_schema]
        )

        result = @app.call_tool("greet", name: "World")
        assert_equal({
          content: [{type: "text", text: "Hello, World!"}],
          isError: false
        }, result)
      end

      def test_register_tool_with_multiple_arguments
        tool = @app.register_tool("format_greeting") do
          description "Format a greeting with title and name"
          argument :title, String, required: true, description: "Title (Mr./Ms./Dr. etc.)"
          argument :first_name, String, required: true, description: "First name"
          argument :last_name, String, required: true, description: "Last name"
          argument :suffix, String, required: false, description: "Name suffix (Jr./Sr./III etc.)"

          call do |args|
            name_parts = [args[:first_name], args[:last_name]]
            name_parts << args[:suffix] if args[:suffix]
            "#{args[:title]} #{name_parts.join(" ")}"
          end
        end

        # Test schema
        assert_equal "format_greeting", tool[:name]
        assert_equal "Format a greeting with title and name", tool[:description]
        assert_equal(
          {
            type: :object,
            properties: {
              title: {
                type: :string,
                description: "Title (Mr./Ms./Dr. etc.)"
              },
              first_name: {
                type: :string,
                description: "First name"
              },
              last_name: {
                type: :string,
                description: "Last name"
              },
              suffix: {
                type: :string,
                description: "Name suffix (Jr./Sr./III etc.)"
              }
            },
            required: [:title, :first_name, :last_name]
          },
          tool[:input_schema]
        )

        # Test with required arguments only
        result = @app.call_tool("format_greeting",
          title: "Dr.",
          first_name: "John",
          last_name: "Smith")
        assert_equal({
          content: [{type: "text", text: "Dr. John Smith"}],
          isError: false
        }, result)

        # Test with optional argument
        result = @app.call_tool("format_greeting",
          title: "Mr.",
          first_name: "John",
          last_name: "Smith",
          suffix: "Jr.")
        assert_equal({
          content: [{type: "text", text: "Mr. John Smith Jr."}],
          isError: false
        }, result)

        # Test with missing required argument
        result = @app.call_tool("format_greeting",
          first_name: "John",
          last_name: "Smith")
        assert result[:isError]
        assert_match(/missing keyword: :title/, result[:content].first[:text])
      end

      def test_tool_without_handler
        error = assert_raises(ArgumentError) do
          @app.register_tool("invalid") do
            description "Invalid tool without handler"
          end
        end
        assert_match(/Handler must be provided/, error.message)
      end

      def test_tool_with_invalid_name
        error = assert_raises(ArgumentError) do
          @app.register_tool(nil) do
            description "Invalid tool"
            call do |args|
              "test"
            end
          end
        end
        assert_match(/Tool name cannot be nil or empty/, error.message)
      end
    end
  end
end
