# frozen_string_literal: true

require_relative "app/resource"
require_relative "app/resource_template"
require_relative "app/tool"

module MCP
  class App
    include Resource
    include ResourceTemplate
    include Tool
  end
end
