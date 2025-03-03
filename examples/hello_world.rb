#!/usr/bin/env ruby
# frozen_string_literal: true
require "httparty"
require_relative "../lib/mcp"

name "hello-world"
version "1.0.0"

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

resource "channels://{channel_id}" do
  name "Get a Channel"
  description "Get the Gaggle channel by channel_id"
  mime_type "text/plain"
  call do |args|  
    channel_id = args[:channel_id]
    uri = URI("#{RAILS_APP_URL}/gaggle/channels/#{channel_id}")
    HTTParty.get(uri, headers: { "Accept" => "application/json" })
  end
end
