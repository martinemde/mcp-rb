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

    def test_invalid_method
      validator = MessageValidator.new

      invalid_message = {
        "jsonrpc" => "2.0",
        "method" => "invalidMethod",
        "params" => {},
        "id" => 1
      }

      assert_raises(MessageValidator::InvalidMethod) do
        validator.validate_client_message!(invalid_message)
      end
    end

    def test_invalid_params
      validator = MessageValidator.new

      invalid_message = {
        "jsonrpc" => "2.0",
        "method" => "resources/read",
        "params" => {"invalid_param" => "value"},
        "id" => 1
      }

      assert_raises(MessageValidator::InvalidParams) do
        validator.validate_client_message!(invalid_message)
      end
    end
  end
end
