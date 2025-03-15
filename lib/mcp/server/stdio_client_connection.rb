# frozen_string_literal: true

module MCP
  class Server
    # Implementation of the stdio transport for the MCP server.
    # @see ClientConnection
    class StdioClientConnection
      include ClientConnection

      def initialize
        # Ensure output is flushed immediately
        $stdout.sync = true
      end

      def read_next_message
        # gets will return nil if the client closes the connection
        $stdin.gets&.chomp
      end

      def send_message(message)
        $stdout.puts(message)
      end
    end
  end
end
