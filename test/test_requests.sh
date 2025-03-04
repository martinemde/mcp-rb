#!/bin/bash

{
# Initialize request
echo '{"jsonrpc": "2.0", "method": "initialize", "params": {"protocolVersion": "2024-11-05"}, "id": 1}'

# Initialized notification
echo '{"jsonrpc": "2.0", "method": "notifications/initialized"}'

# List tools request
echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 2}'

# Call greet tool request
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "greet", "arguments": {"name": "World"}}, "id": 3}'

# List resources request
echo '{"jsonrpc": "2.0", "method": "resources/list", "id": 4}'

# Read resource request
echo '{"jsonrpc": "2.0", "method": "resources/read", "params": {"uri": "hello://world"}, "id": 5}'

# List resources templates request
echo '{"jsonrpc": "2.0", "method": "resources/templates/list", "id": 6}'

# Read resource template request
echo '{"jsonrpc": "2.0", "method": "resources/read", "params": {"uri": "users://test"}, "id": 7 }'

echo '{"jsonrpc": "2.0", "method": "resources/read", "params": {"uri": "users://test/posts/3"}, "id": 9}'
} | ./examples/hello_world.rb 