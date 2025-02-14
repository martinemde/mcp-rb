#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/mcp"

name "hello-world"

tool "greet" do
  description "Greet someone by name"
  argument :name, String, required: true, description: "Name to greet"

  call do |args|
    "Hello, #{args[:name]}!"
  end
end

resource "hello://world" do
  name "Hello World"
  description "A simple hello world message"
  mime_type "text/plain"
  call { "Hello, World!" }
end
