# frozen_string_literal: true

require "json_schemer"

module MCP
  class MessageValidator
    SCHEMA_ROOT_PATH = File.expand_path(File.join("..", "..", "schemas"), __dir__)

    def initialize(protocol_version: Constants::PROTOCOL_VERSION)
      schema_path = File.join(SCHEMA_ROOT_PATH, "#{protocol_version}.json")
      @root_schema = JSONSchemer.schema(Pathname.new(schema_path))
    end

    def validate_client_message!(message)
      ensure_minimal_client_message_requirements!(message)
    end

    class InvalidMessage < StandardError
      attr_reader :errors

      def initialize(errors)
        super(errors.map { _1["error"] }.join(", "))
        @errors = errors.map { _1["error"] }
      end
    end

    private

    def ensure_minimal_client_message_requirements!(message)
      # Validate against notification since it's the minimum requirement for a valid JSON-RPC message
      errors = validation_errors(message, "JSONRPCNotification")
      raise InvalidMessage.new(errors) if errors.any?
    end

    def matching_sub_schema?(json, sub_schema_name)
      sub_schema = sub_schema(sub_schema_name)
      sub_schema.valid?(json)
    end

    def validation_errors(json, sub_schema_name)
      sub_schema = sub_schema(sub_schema_name)
      sub_schema.validate(json).to_a.map { _1.except("schema", "root_schema") }
    end

    def sub_schema(name)
      @root_schema.ref("#/definitions/#{name}")
    end
  end
end
