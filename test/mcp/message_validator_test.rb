# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class MessageValidatorTest < MCPTest::TestCase
    def test_invalid_message
      validator = MessageValidator.new

      invalid_message = {"not" => "a jsonrpc message"}

      assert_raises(MessageValidator::InvalidMessage) do
        validator.validate_client_message!(invalid_message)
      end
    end
  end
end