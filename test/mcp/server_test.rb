# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class ServerTest < MCPTest::TestCase
    def test_server_version
      app = configure_test_app(version: "1.2.3")

      # Test the server version directly
      server = Server.new(app)
      assert_equal "1.2.3", server.version

      # Test the version returned in the initialize response
      response = initialization_response(app)
      assert_equal "1.2.3", response[:result][:serverInfo][:version]
    end

    def test_basic_server_info
      app = configure_test_app(
        name: "special_test_server",
        version: "1.4.1"
      )
      server = Server.new(app)

      assert_equal "special_test_server", server.name
      assert_equal "1.4.1", server.version
    end

    def test_responds_with_server_info_on_initialize
      app = configure_test_app(
        name: "special_test_server",
        version: "1.4.1"
      )
      response = initialization_response(app)

      expected = {
        name: "special_test_server",
        version: "1.4.1"
      }
      assert_equal expected, response[:result][:serverInfo]
    end

    def test_supports_tools_without_list_changed
      app = App.new
      response = initialization_response(app)

      expected = {listChanged: false}
      assert_equal expected, response[:result][:capabilities][:tools]
    end

    def test_supports_resources_without_sub_capabilities
      app = App.new
      response = initialization_response(app)

      expected = {
        subscribe: false,
        listChanged: false
      }
      assert_equal expected, response[:result][:capabilities][:resources]
    end

    def test_does_not_support_prompts
      app = App.new
      response = initialization_response(app)

      refute_includes response[:result][:capabilities].keys, :prompts
    end

    def test_does_not_support_logging
      app = App.new
      response = initialization_response(app)

      refute_includes response[:result][:capabilities].keys, :logging
    end

    def test_does_not_allow_unsupported_protocol_version
      app = App.new
      client = create_uninitialized_test_client(app)

      # Send initialize with bad protocol version
      response = client.send_initialize("1999-01-01")

      assert response[:error]
      assert_equal Constants::ErrorCodes::INVALID_PARAMS, response[:error][:code]
      assert_equal "Unsupported protocol version", response[:error][:message]
    end

    def test_does_not_allow_non_ping_requests_before_initialize
      app = App.new
      client = create_uninitialized_test_client(app)

      # Send tools list without initialization
      response = client.list_tools

      assert response[:error]
      assert_equal Constants::ErrorCodes::NOT_INITIALIZED, response[:error][:code]
      assert_equal "Server not initialized", response[:error][:message]
    end

    def test_allows_ping_requests_before_initialize
      app = App.new
      client = create_uninitialized_test_client(app)

      # Send ping without initialization
      response = client.send_ping

      assert_successful_response response
    end

    def test_does_not_allow_non_json_messages
      app = App.new
      client = create_uninitialized_test_client(app)

      # Send invalid JSON
      response = client.send_raw_message("not json")

      assert response[:error]
      assert_equal Constants::ErrorCodes::PARSE_ERROR, response[:error][:code]
      assert_includes response[:error][:message], "Invalid JSON"
    end

    private

    def assert_successful_response(response)
      assert response[:result]
    end
  end
end
