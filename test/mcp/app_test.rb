# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class ServerTest < MCPTest::TestCase
    def teardown
      App.reset!
    end

    def test_app_version
      App.version("1.2.3")
      app = App.new

      assert_equal "1.2.3", app.version
    end

    def test_app_name_and_version
      App.name("special_test_server")
      App.version("1.4.1")

      app = App.new

      assert_equal "special_test_server", app.name
      assert_equal "1.4.1", app.version
    end
  end
end
