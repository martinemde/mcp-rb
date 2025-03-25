# frozen_string_literal: true

require "addressable/template"
require_relative "resource"

module MCP
  class App
    # Include this module in your app to add resource template functionality
    module ResourceTemplate
      def self.included(base)
        base.include(MCP::App::Resource)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def resource_templates
          @resource_templates ||= {}
        end

        def resource_template(resource_template, &block)
          resource_template = ResourceTemplateBuilder.new(resource_template, &block) if block_given?

          resource_template_hash = resource_template.to_h
          uri_template = resource_template_hash[:uri_template]

          raise ArgumentError, "Resource URI template cannot be nil or empty" if uri_template.nil? || uri_template.empty?
          raise ArgumentError, "Handler must be provided" if resource_template_hash[:handler].nil?
          raise ArgumentError, "Name must be provided" if resource_template_hash[:name].empty?

          template = Addressable::Template.new(uri_template)
          resource_templates[template] = resource_template_hash
        end

        def reset!
          @resource_templates = nil
        end
      end

      class ResourceTemplateBuilder
        attr_reader :uri_template, :handler

        def initialize(uri_template, &block)
          raise ArgumentError, "Resource URI template cannot be nil or empty" if uri_template.nil? || uri_template.empty?
          @uri_template = uri_template
          @name = ""
          @description = ""
          @mime_type = "text/plain"
          @handler = nil
          instance_eval(&block) if block_given?
        end

        # standard:disable Style/TrivialAccessors
        def name(value)
          @name = value
        end

        def description(text)
          @description = text
        end

        def mime_type(value)
          @mime_type = value
        end
        # standard:enable Style/TrivialAccessors

        def call(&block)
          @handler = block
        end

        def to_h
          {
            uri_template: @uri_template,
            name: @name,
            mime_type: @mime_type,
            description: @description,
            handler: @handler,
          }
        end
      end

      def resource_templates
        self.class.resource_templates
      end

      # Find a template that matches the given URI and extract variable values
      def find_matching_template(uri)
        resource_templates.each do |template, resource_template|
          variable_values = template.extract(uri)
          next if variable_values.nil? || variable_values.empty?

          return [resource_template, variable_values.transform_keys(&:to_sym)]
        end
        [nil, {}]
      end

      def list_resource_templates(cursor: nil, page_size: nil)
        start_index = cursor&.to_i || 0
        values = resource_templates.values

        if page_size.nil?
          paginated = values[start_index..]
          next_cursor = nil
        else
          paginated = values[start_index, page_size]
          has_next = start_index + page_size < values.length
          next_cursor = has_next ? (start_index + page_size).to_s : nil
        end

        {
          resourceTemplates: paginated.map { |t| format_resource_template(t) },
          nextCursor: next_cursor
        }.compact
      end

      private

      def format_resource_template(template)
        {
          uriTemplate: template[:uri_template],
          name: template[:name],
          description: template[:description],
          mimeType: template[:mime_type]
        }
      end
    end
  end
end
