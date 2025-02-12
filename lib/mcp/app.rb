# frozen_string_literal: true

require_relative "app/resource"
require_relative "app/tool"

module MCP
  class App
    include Resource
    include Tool
  end
end
