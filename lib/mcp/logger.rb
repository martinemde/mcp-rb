module MCP
  class Logger

    def self.log(message)
      log_file.puts(message)
    end

    private

    def self.log_file
      @log_file ||= File.open("debug", "a") || raise("Cannot open debug file")
      @log_file.sync = true
      @log_file
    end
  end
end