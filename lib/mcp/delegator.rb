# frozen_string_literal: true

module MCP
  module Delegator
    def self.delegate(*methods)
      methods.each do |method_name|
        define_method(method_name) do |*args, **kwargs, &block|
          # name が呼ばれたら Server インスタンスを生成
          # もうすこしいい感じにしたい
          if method_name == :name && !MCP.server
            MCP.initialize_server(name: args.first || "default")
          end
          MCP.server.send(method_name, *args, **kwargs, &block)
        end
      end
    end

    delegate :name, :resource, :tool
  end
end
