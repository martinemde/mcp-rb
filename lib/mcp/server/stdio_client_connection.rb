# frozen_string_literal: true

module MCP
  class Server
    # Implementation of the stdio transport for the MCP server.
    class StdioClientConnection
      include ClientConnection

      def initialize
        # Ensure output is flushed immediately
        $stdout.sync = true
      end

      def read_next_message
        $stdin.gets&.chomp
      end

      def send_message(message)
        $stdout.puts(message)
      end
    end
  end
end
