# frozen_string_literal: true

module MCP
  class App
    module Tool
      def tools
        @tools ||= {}
      end

      class ToolBuilder
        attr_reader :name, :description, :arguments, :handler

        def initialize(name)
          raise ArgumentError, "Tool name cannot be nil or empty" if name.nil? || name.empty?
          @name = name
          @description = ""
          @arguments = {}
          @required_arguments = []
          @handler = nil
        end

        # standard:disable Lint/DuplicateMethods
        def description(text = nil)
          return @description if text.nil?
          @description = text
        end
        # standard:enable Lint/DuplicateMethods

        def argument(name, type, required: false, description: "")
          @arguments[name] = {
            type: ruby_type_to_schema_type(type),
            description: description
          }
          @required_arguments << name if required
        end

        def call(&block)
          @handler = block if block_given?
        end

        def to_tool_hash
          raise ArgumentError, "Handler must be provided" unless @handler
          {
            name: @name,
            description: @description,
            input_schema: {
              type: :object,
              properties: @arguments,
              required: @required_arguments
            },
            handler: @handler
          }
        end

        private

        def ruby_type_to_schema_type(type)
          case type.to_s
          when "String" then :string
          when "Integer" then :integer
          when "Float" then :number
          when "TrueClass", "FalseClass", "Boolean" then :boolean
          else :object
          end
        end
      end

      def register_tool(name, &block)
        builder = ToolBuilder.new(name)
        builder.instance_eval(&block)
        tool_hash = builder.to_tool_hash
        tools[name] = tool_hash
        tool_hash
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
          validate_arguments(tool[:input_schema], arguments)
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

      def validate_arguments(schema, arguments)
        return unless schema[:required]

        schema[:required].each do |required_arg|
          unless arguments.key?(required_arg)
            raise ArgumentError, "missing keyword: :#{required_arg}"
          end
        end
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
