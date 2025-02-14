# frozen_string_literal: true

module MCP
  class App
    module Resource
      def resources
        @resources ||= {}
      end

      class ResourceBuilder
        attr_reader :uri, :name, :description, :mime_type, :handler

        def initialize(uri)
          raise ArgumentError, "Resource URI cannot be nil or empty" if uri.nil? || uri.empty?
          @uri = uri
          @name = ""
          @description = ""
          @mime_type = "text/plain"
          @handler = nil
        end

        # standard:disable Lint/DuplicateMethods,Style/TrivialAccessors
        def name(value)
          @name = value
        end
        # standard:enable Lint/DuplicateMethods,Style/TrivialAccessors

        # standard:disable Lint/DuplicateMethods,Style/TrivialAccessors
        def description(text)
          @description = text
        end
        # standard:enable Lint/DuplicateMethods,Style/TrivialAccessors

        # standard:disable Lint/DuplicateMethods,Style/TrivialAccessors
        def mime_type(value)
          @mime_type = value
        end
        # standard:enable Lint/DuplicateMethods,Style/TrivialAccessors

        def call(&block)
          @handler = block
        end

        def to_resource_hash
          raise ArgumentError, "Handler must be provided" unless @handler
          raise ArgumentError, "Name must be provided" if @name.empty?

          {
            uri: @uri,
            name: @name,
            mime_type: @mime_type,
            description: @description,
            handler: @handler
          }
        end
      end

      def register_resource(uri, &block)
        builder = ResourceBuilder.new(uri)
        builder.instance_eval(&block)
        resource_hash = builder.to_resource_hash
        resources[uri] = resource_hash
        resource_hash
      end

      def list_resources(cursor: nil, page_size: nil)
        start_index = cursor&.to_i || 0
        values = resources.values

        if page_size.nil?
          paginated = values[start_index..]
          next_cursor = ""
        else
          paginated = values[start_index, page_size]
          has_next = start_index + page_size < values.length
          next_cursor = has_next ? (start_index + page_size).to_s : ""
        end

        {
          resources: paginated.map { |r| format_resource(r) },
          nextCursor: next_cursor
        }
      end

      def read_resource(uri)
        resource = resources[uri]
        raise ArgumentError, "Resource not found: #{uri}" unless resource

        begin
          content = resource[:handler].call
          {
            contents: [{
              uri: resource[:uri],
              mimeType: resource[:mime_type],
              text: content
            }]
          }
        rescue => e
          raise ArgumentError, "Error reading resource: #{e.message}"
        end
      end

      private

      def format_resource(resource)
        {
          uri: resource[:uri],
          name: resource[:name],
          description: resource[:description],
          mimeType: resource[:mime_type]
        }
      end
    end
  end
end
