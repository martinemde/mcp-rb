# frozen_string_literal: true

require "English"
require "json"

require_relative "mcp/version"
require_relative "mcp/constants"
require_relative "mcp/autorun"
require_relative "mcp/app"
require_relative "mcp/server"
require_relative "mcp/delegator"
require_relative "mcp/client"

module MCP
  extend MCP::Autorun
  @app_file = cleaned_caller(1).flatten.first
  class << self
    def server
      @server ||= Server.new(App.new)
    end

    def serve
      server.serve(Server::StdioClientConnection.new)
    end

    def run?
      File.expand_path($PROGRAM_NAME) == File.expand_path(@app_file) && $ERROR_INFO.nil? && $stdin.stat.readable?
    end
  end

  at_exit do
    serve if run?
  end
end

extend MCP::Delegator # standard:disable Style/MixinUsage
