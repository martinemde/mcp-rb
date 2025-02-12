#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/mcp"

name "hello-world"

tool "greet",
  description: "Greet someone by name",
  input_schema: {
    type: :object,
    properties: {
      name: {
        type: :string,
        description: "Name to greet"
      }
    },
    required: [:name]
  } do |args|
  "Hello, #{args[:name]}!"
end

# リソースの定義
resource "hello://world",
  name: "Hello World",
  description: "A simple hello world message" do
  "Hello, World!"
end
