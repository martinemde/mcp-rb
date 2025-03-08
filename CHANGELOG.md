# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2025-03-07

### Added
- Add support for Nested Arguments and Array Arguments: https://github.com/funwarioisii/mcp-rb/pull/6
  - Add validation for nested arguments
  - Support array type arguments

## [0.3.1] - 2025-03-05

### Added
- Add `resources/templates/list` method: https://github.com/funwarioisii/mcp-rb/pull/5

## [0.3.0] - 2025-02-19

- Allow specifying the version via DSL keyword: https://github.com/funwarioisii/mcp-rb/pull/2
- Add MCP Client: https://github.com/funwarioisii/mcp-rb/pull/3

### Breaking Changes
- `MCP::PROTOCOL_VERSION` is moved to `MCP::Constants::PROTOCOL_VERSION`
  - https://github.com/funwarioisii/mcp-rb/pull/3/commits/caad65500935a8eebfe024dbd25de0d16868c44e

## [0.2.0] - 2025-02-14

### Breaking Changes
- Unified DSL to block-based style for both tools and resources
  - Example of new resource style:
    ```ruby
    resource "uri" do
      name "Resource Name"
      description "Description"
      mime_type "text/plain"
      call { "content" }
    end
    ```
  - Example of new tool style:
    ```ruby
    tool "greet" do
      description "Greet someone"
      argument :name, String, required: true, description: "Name to greet"
      call do |args|
        "Hello, #{args[:name]}!"
      end
    end
    ```

## [0.1.0] - 2025-02-12

### Added
- Initial release
