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

      all_errors = client_message_validation_errors(message)
      return if all_errors.empty?

      params_errors = params_errors_of_matching_sub_schema(message, all_errors)
      raise InvalidMethod if params_errors.empty?
      raise InvalidParams.new(params_errors)
    end

    class InvalidMessage < StandardError
      attr_reader :errors

      def initialize(errors)
        super(errors.map { _1["error"] }.join(", "))
        @errors = errors.map { _1["error"] }
      end
    end

    class InvalidMethod < StandardError; end

    class InvalidParams < InvalidMessage; end

    private

    def ensure_minimal_client_message_requirements!(message)
      # Validate against notification since it's the minimum requirement for a valid JSON-RPC message
      errors = validation_errors(message, "JSONRPCNotification")
      raise InvalidMessage.new(errors) if errors.any?
    end

    def client_message_validation_errors(message)
      if message.key? "id"
        validation_errors(message, "ClientRequest")
      else
        validation_errors(message, "ClientNotification")
      end
    end

    def params_errors_of_matching_sub_schema(message, all_errors)
      # JSON Schemer returns errors for all sub-schemas if none of them match the data.
      # So we need to check if all each sub-schema has at least one error for the "/method" data pointer.
      errors_grouped_by_sub_schema = all_errors.group_by {
        # /definitions/SubSchemaName/...
        _, _, sub_schema, = _1["schema_pointer"].split("/")
        sub_schema
      }

      result = []
      errors_grouped_by_sub_schema.each do |sub_schema_name, errors|
        next if errors.any? { _1["data_pointer"] == "/method" }

        result = errors
        break
      end
      result
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
