# [WIP] This example is not working yet.
# Prerequisites:
# - Install Playwright: https://playwright.dev/ruby/docs/intro#installation

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "playwright-ruby-client"
  gem "nokogiri", "~> 1.18"
  gem "reverse_markdown", "~> 3.0"
  gem "html2haml", "~> 2.3"
  gem "base64"
end

require "playwright"
require "fileutils"
require "nokogiri"
require "reverse_markdown"
require "html2haml"
require_relative "../lib/mcp"

class BrowserSession
  USER_DATA_DIR = "#{ENV["HOME"]}/.browser-use-rb"
  PLAYWRIGHT_PATH = "/opt/homebrew/bin/playwright"
  PLAYWRIGHT_ARGS = {
    headless: false,
    args: %w[--disable-blink-features=AutomationControlled --no-sandbox],
    userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    viewport: {width: 1280, height: 800},
    locale: "ja-JP",
    deviceScaleFactor: 2,
    isMobile: false
  }

  attr_reader :page, :context, :playwright_exec

  def initialize
    warn "Initializing BrowserSession..."
    unless Dir.exist?(USER_DATA_DIR)
      FileUtils.mkdir_p(USER_DATA_DIR)
    end

    unless File.exist?(PLAYWRIGHT_PATH)
      raise "Playwright が見つかりません: #{PLAYWRIGHT_PATH}"
    end

    ReverseMarkdown.config do |config|
      config.unknown_tags = :bypass
      config.github_flavored = true
      config.tag_border = ""
    end

    setup_browser
  end

  def search_by_duckduckgo(query)
    @page.goto("https://duckduckgo.com?q=#{query}")
    html = @page.content
    doc = Nokogiri::HTML(html)

    articles = doc.xpath("//article")
    article_datas = articles.map do |article|
      title_element = article.at_xpath(".//h2/a")
      title = title_element&.text&.strip
      url = title_element&.attr("href")

      description = article.at_xpath(".//div[@data-result='snippet']")&.text&.strip
      sublinks = article
        .xpath(".//ul//a")
        .map { |link| {text: link.text.strip, url: link.attr("href")} }

      content_parts = []
      content_parts << "[#{title}](#{url})" if title && url
      content_parts << description if description

      if sublinks.any?
        content_parts << "\n\n関連リンク:"
        sublinks.each do |link|
          content_parts << "- [#{link[:text]}](#{link[:url]})"
        end
      end

      content_parts.join("\n")
    end

    article_datas.join("\n\n")
  end

  def open_url(url)
    begin
      if current_url == url
        # reload
        @page.reload
      else
        @page.goto(url)
      end
    rescue => e
      warn "Error during page.goto: #{e.class} - #{e.message}"
      warn e.backtrace.join("\n")
      raise
    end
    @page.wait_for_timeout(1_000)

    html = @page.content
    doc = Nokogiri::HTML(html)
    doc_in_main = doc.at_xpath("//main")
    return "Content could not be read" unless doc_in_main

    html = doc_in_main.to_html
    ReverseMarkdown.convert(html)
  end

  def open_url_raw(url)
    warn "[open_url_raw]Opening URL: #{url}"
    @page.goto(url)
    @page.content
  end

  def open_url_raw_haml(url)
    warn "[open_url_raw_haml]Opening URL: #{url}"
    @page.goto(url)
    html = @page.content
    Html2haml::HTML.new(html).render
  end

  def click_by_selector(selector)
    @page.click(selector)
  end

  def current_url
    @page.url
  end

  def close
    warn "Closing browser session..."
    @context&.close
    @playwright_exec&.stop
    warn "Browser session closed"
  end

  private

  def setup_browser
    warn "Setting up browser..."
    begin
      @playwright_exec = Playwright.create(playwright_cli_executable_path: PLAYWRIGHT_PATH)
      @context = @playwright_exec.playwright.chromium.launch_persistent_context(USER_DATA_DIR, **PLAYWRIGHT_ARGS)
      @page = @context.pages.first || @context.new_page
    rescue => e
      warn "Error during browser setup: #{e.class} - #{e.message}"
      warn e.backtrace.join("\n")
      raise
    end
  end
end

browser = BrowserSession.new

name "browser-use"

tool "open-url" do
  description "Open a URL in the browser. The result is converted to markdown."
  argument :url, String, description: "The URL to open"
  call { browser.open_url(it[:url]) }
end

tool "open-url-raw" do
  description "Open a URL in the browser. The result is raw HTML."
  argument :url, String, description: "The URL to open"
  call { browser.open_url_raw(it[:url]) }
end
