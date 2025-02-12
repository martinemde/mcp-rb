# frozen_string_literal: true

module MCP
  class App
    module Tool
      def register_tool(name, description: "", input_schema: {}, &block)
        raise ArgumentError, "Tool name cannot be nil or empty" if name.nil? || name.empty?
        raise ArgumentError, "Block must be provided" unless block_given?

        tools[name] = {
          name: name,
          description: description,
          input_schema: input_schema,
          handler: block
        }
      end

      def list_tools(cursor: nil, page_size: 10)
        tool_values = tools.values
        start_index = cursor ? cursor.to_i : 0
        paginated = tool_values[start_index, page_size]
        next_cursor = (start_index + page_size < tool_values.length) ? (start_index + page_size).to_s : ""

        {
          tools: paginated.map { |t| format_tool(t) },
          nextCursor: next_cursor
        }
      end

      def call_tool(name, **arguments)
        tool = tools[name]
        raise ArgumentError, "Tool not found: #{name}" unless tool

        begin
          result = tool[:handler].call(arguments)
          {
            content: [
              {
                type: "text",
                text: result.to_s
              }
            ],
            isError: false
          }
        rescue => e
          {
            content: [
              {
                type: "text",
                text: "Error: #{e.message}"
              }
            ],
            isError: true
          }
        end
      end

      private

      def tools
        @tools ||= {}
      end

      def format_tool(tool)
        {
          name: tool[:name],
          description: tool[:description],
          inputSchema: tool[:input_schema]
        }
      end
    end
  end
end
