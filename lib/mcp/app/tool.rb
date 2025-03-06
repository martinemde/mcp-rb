# frozen_string_literal: true

module MCP
  class App
    module Tool
      def tools
        @tools ||= {}
      end

      # Builds schemas for arguments, supporting simple types, nested objects, and arrays
      class SchemaBuilder
        def initialize
          @schema = nil
          @properties = {}
          @required = []
        end

        def argument(name, type = nil, required: false, description: "", items: nil, &block)
          if type == Array
            if block_given?
              sub_builder = SchemaBuilder.new
              sub_builder.instance_eval(&block)
              item_schema = sub_builder.to_schema
            elsif items
              item_schema = {type: ruby_type_to_schema_type(items)}
            else
              raise ArgumentError, "Must provide items or a block for array type"
            end
            @properties[name] = {type: :array, description: description, items: item_schema}
          elsif block_given?
            raise ArgumentError, "Type not allowed with block for objects" if type
            sub_builder = SchemaBuilder.new
            sub_builder.instance_eval(&block)
            @properties[name] = sub_builder.to_schema.merge(description: description)
          else
            raise ArgumentError, "Type required for simple arguments" if type.nil?
            @properties[name] = {type: ruby_type_to_schema_type(type), description: description}
          end
          @required << name if required
        end

        def type(t)
          @schema = {type: ruby_type_to_schema_type(t)}
        end

        def to_schema
          @schema || {type: :object, properties: @properties, required: @required}
        end

        private

        def ruby_type_to_schema_type(type)
          if type == String
            :string
          elsif type == Integer
            :integer
          elsif type == Float
            :number
          elsif type == TrueClass || type == FalseClass
            :boolean
          elsif type == Array
            :array
          else
            raise ArgumentError, "Unsupported type: #{type}"
          end
        end
      end

      # Constructs tool definitions with enhanced schema support
      class ToolBuilder
        attr_reader :name, :arguments, :handler

        def initialize(name)
          raise ArgumentError, "Tool name cannot be nil or empty" if name.nil? || name.empty?
          @name = name
          @description = ""
          @schema_builder = SchemaBuilder.new
          @handler = nil
        end

        def description(text = nil)
          text ? @description = text : @description
        end

        def argument(*args, **kwargs, &block)
          @schema_builder.argument(*args, **kwargs, &block)
        end

        def call(&block)
          @handler = block if block_given?
        end

        def to_tool_hash
          raise ArgumentError, "Handler must be provided" unless @handler
          {
            name: @name,
            description: @description,
            input_schema: @schema_builder.to_schema,
            handler: @handler
          }
        end
      end

      # Registers a tool with the given name and block
      def register_tool(name, &block)
        builder = ToolBuilder.new(name)
        builder.instance_eval(&block)
        tools[name] = builder.to_tool_hash
      end

      # Lists tools with pagination
      def list_tools(cursor: nil, page_size: 10)
        start = cursor ? cursor.to_i : 0
        paginated = tools.values[start, page_size]
        next_cursor = (start + page_size < tools.length) ? (start + page_size).to_s : nil
        {tools: paginated.map { |t| {name: t[:name], description: t[:description], inputSchema: t[:input_schema]} }, nextCursor: next_cursor}
      end

      # Calls a tool with the provided arguments
      def call_tool(name, **args)
        tool = tools[name]
        raise ArgumentError, "Tool not found: #{name}" unless tool

        validate_arguments(tool[:input_schema], args)
        {content: [{type: "text", text: tool[:handler].call(args).to_s}], isError: false}
      rescue => e
        {content: [{type: "text", text: "Error: #{e.message}"}], isError: true}
      end

      private

      def validate_arguments(schema, args)
        schema[:required]&.each { |req| raise ArgumentError, "Missing keyword: :#{req}" unless args.key?(req) }
      end
    end
  end
end
