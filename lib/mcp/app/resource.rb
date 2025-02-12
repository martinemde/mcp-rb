# frozen_string_literal: true

module MCP
  class App
    module Resource
      def register_resource(uri, name:, mime_type: "text/plain", description: "", &block)
        raise ArgumentError, "Resource name cannot be nil or empty" if uri.nil? || uri.empty?
        raise ArgumentError, "Block must be provided" unless block_given?

        resources[uri] = {
          uri:, name:, mime_type:, description:,
          handler: block
        }
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

      def resources
        @resources ||= {}
      end

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
