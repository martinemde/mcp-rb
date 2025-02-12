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
require 'mcp-rb'

name "hello-world"

# リソースの定義
resource "hello://world",
  name: "Hello World",
  description: "A simple hello world message" do
  "Hello, World!"
end

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
