# frozen_string_literal: true

require_relative "../../test_helper"

module MCP
  class App
    class ResourceTemplateTest < MCPTest::TestCase
      def setup
        @app = App.new
      end

      def test_register_and_list_resource_templates
        @app.register_resource_template("/test/{test_variable}") do
          name "test_resource template"
          description "A test resource template"
          call { |args| "test content #{args[:test_variable]}" }
        end

        result = @app.list_resource_templates
        templates = result[:resourceTemplates]

        assert_equal 1, templates.length
        assert_equal "/test/{test_variable}", templates.first[:uriTemplate]
        assert_equal "test_resource template", templates.first[:name]
        assert_equal "A test resource template", templates.first[:description]
        assert_equal "", result[:nextCursor]
      end

      def test_resource_templates_pagination
        10.times do |i|
          @app.register_resource_template("/test#{i}/{test_variable}") do
            name "resource#{i}"
            call { |args| "content#{i} #{args[:test_variable]}" }
          end
        end

        # Test without page_size (should return all resources)
        result = @app.list_resource_templates
        templates = result[:resourceTemplates]

        assert_equal 10, templates.length
        assert_equal "/test0/{test_variable}", templates.first[:uriTemplate]
        assert_equal "resource0", templates.first[:name]
        assert_equal "", result[:nextCursor]

        # First page
        result = @app.list_resource_templates(page_size: 5)
        assert_equal 5, result[:resourceTemplates].length
        assert_equal "/test0/{test_variable}", result[:resourceTemplates].first[:uriTemplate]
        assert_equal "resource0", result[:resourceTemplates].first[:name]
        assert_equal "5", result[:nextCursor]

        # Second page
        result = @app.list_resource_templates(page_size: 5, cursor: "5")
        assert_equal 5, result[:resourceTemplates].length
        assert_equal "/test5/{test_variable}", result[:resourceTemplates].first[:uriTemplate]
        assert_equal "resource5", result[:resourceTemplates].first[:name]
        assert_equal "", result[:nextCursor]
      end

      def test_read_resource_template
        @app.register_resource_template("/test/{test_variable}") do
          name "test_resource"
          call { |args| "test content #{args[:test_variable]}" }
        end

        result = @app.read_resource("/test/hello")

        assert_equal "/test/hello", result[:contents].first[:uri]
        assert_equal "test content hello", result[:contents].first[:text]

        error = assert_raises(ArgumentError) { @app.read_resource("/non_existent") }
        assert_match(/Resource not found/, error.message)
      end

      def test_invalid_resource_registration
        error = assert_raises(ArgumentError) { @app.register_resource(nil) }
        assert_match(/Resource URI cannot be nil or empty/, error.message)

        error = assert_raises(ArgumentError) { @app.register_resource("") }
        assert_match(/Resource URI cannot be nil or empty/, error.message)

        error = assert_raises(ArgumentError) do
          @app.register_resource("/test") do
            # nameとhandlerが設定されていない
          end
        end
        assert_match(/Handler must be provided/, error.message)

        error = assert_raises(ArgumentError) do
          @app.register_resource("/test") do
            call { "test" }
            # nameが設定されていない
          end
        end
        assert_match(/Name must be provided/, error.message)
      end
    end
  end
end
