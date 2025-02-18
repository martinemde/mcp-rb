#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/mcp"

begin
  client = MCP::Client.new(
    command: "ruby",
    args: ["examples/hello_world.rb"]
  )
  client.connect

  tools = client.list_tools
  puts "available tools:"
  puts tools.inspect

  # execute greet tool
  result = client.call_tool(
    name: "greet",
    args: {name: "MCP Client Example"}
  )
  puts "\nResult:"
  puts result.inspect
ensure
  client.close
end
