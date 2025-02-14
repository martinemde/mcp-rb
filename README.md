# MCP-RB

A lightweight Ruby framework for implementing MCP (Model Context Protocol) servers with a Sinatra-like DSL.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mcp-rb'
```

## Usage

Here's a simple example of how to create an MCP server:

```ruby
require 'mcp'

name "hello-world"

# Define a resource
resource "hello://world" do
  name "Hello World"
  description "A simple hello world message"
  call { "Hello, World!" }
end

# Define a tool
tool "greet" do
  description "Greet someone by name"
  argument :name, String, required: true, description: "Name to greet"
  call do |args|
    "Hello, #{args[:name]}!"
  end
end
```

## Testing

```bash
ruby -Ilib:test -e "Dir.glob('./test/**/*_test.rb').each { |f| require f }"
```

Test with MCP Inspector

```bash
bunx @modelcontextprotocol/inspector $(pwd)/examples/hello_world.rb
```

Find broken using `hello_world.rb`

```bash
./test/test_requests.sh
```

## Formatting

```bash
bundle exec standardrb --fix
```

## Release

To release a new version:

1. Update version in `lib/mcp/version.rb`
2. Update `CHANGELOG.md`
3. Create a git tag

```bash
git add .
git commit -m "Release vx.y.z"
git tag vx.y.z
git push --tags
```

1. Build and push to RubyGems

```bash
gem build mcp-rb.gemspec
gem push mcp-rb-*.gem
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md)

