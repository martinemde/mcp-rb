#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require_relative "../lib/mcp"

project_name = ENV["COSENSE_PROJECT_NAME"] || "funwarioisii"
cosense_sid = ENV["COSENSE_SID"]

# Cosense APIクライアント
module CosenseClient
  BASE_URL = "https://scrapbox.io/api"
  TIMEOUT = 5 # seconds

  def self.get_page(project_name, page_name, sid = nil)
    encoded_page_name = URI.encode_www_form_component(page_name.tr(" ", "_"))
    warn "Fetching page: #{project_name}/#{page_name}"
    url = "#{BASE_URL}/pages/#{project_name}/#{encoded_page_name}"
    make_request(url, sid)
  end

  def self.list_pages(project_name, sid = nil)
    make_request("#{BASE_URL}/pages/#{project_name}", sid)
  end

  def self.to_readable_page(page)
    return {title: "Error", description: "Page not found or error occurred"} unless page

    title_and_description = <<~TEXT
      #{page[:title]}
      ---
      #{page[:lines].map { |line| line[:text] }.join("\n")}
    TEXT

    related_pages = if page[:links]&.any?
      <<~TEXT
        ## 関連するページのタイトル
        #{page[:links].join("\n")}
      TEXT
    else
      ""
    end

    {
      title: page[:title],
      description: title_and_description + related_pages
    }
  end

  def self.make_request(url, sid = nil)
    uri = URI(url)
    headers = sid ? {"Cookie" => "connect.sid=#{sid}"} : {}

    begin
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = TIMEOUT
        http.read_timeout = TIMEOUT
        request = Net::HTTP::Get.new(uri, headers)
        http.request(request)
      end
      warn "Response status: #{response.code} #{response.message}"

      return nil unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError => e
      warn "JSON parse error: #{e.message}"
      nil
    rescue => e
      warn "Error: #{e.class} - #{e.message}"
      warn e.backtrace.join("\n")
      nil
    ensure
      response&.body&.close if response&.body.respond_to?(:close)
    end
  end
end

# ここから本題

name "cosense-mcp-server"

# ページ一覧を取得してリソースとして登録
cosense_resources = CosenseClient.list_pages(project_name, cosense_sid)

if cosense_resources
  # ページ参照時にアクセス
  cosense_resources[:pages].each do |page|
    resource "cosense://#{page[:title]}",
      name: page[:title],
      description: "A text page: #{page[:title]}" do
      page_data = CosenseClient.get_page(project_name, page[:title], cosense_sid)
      readable_page = CosenseClient.to_readable_page(page_data)
      readable_page[:description]
    end
  end
else
  warn "No pages found or error occurred while fetching pages"
end

# ツールの定義
tool "get_page",
  description: <<~DESC,
    Get a page from #{project_name} project on cosen.se
    In cosense, a page is a cosense-style document with a title and a description.
    Bracket Notation makes links between pages.

    Example:
      [Page Title] -> "/#{project_name}/Page Title"
      [https://example.com] -> "https://example.com"
      [example https://example.com] -> "https://example.com"

    A page may have links to other pages.
    Links are rendered at the bottom of the page.
  DESC
  input_schema: {
    type: :object,
    properties: {
      page_title: {
        type: :string,
        description: "Title of the page"
      }
    },
    required: [:page_title]
  } do |args|
  page = CosenseClient.get_page(project_name, args[:page_title], cosense_sid)
  raise "Page #{args[:page_title]} not found" unless page

  readable_page = CosenseClient.to_readable_page(page)

  # ページの内容をリソースとしてキャッシュ
  resource "cosense://#{page[:title]}",
    name: page[:title],
    description: "A text page: #{page[:title]}" do
    readable_page[:description]
  end

  readable_page[:description]
end
