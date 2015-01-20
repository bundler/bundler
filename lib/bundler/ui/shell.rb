module Bundler
  module UI
    class Shell
      LEVELS = %w(silent error warn confirm info debug)

      attr_writer :shell

      def initialize(options = {})
        if options["no-color"] || !STDOUT.tty?
          Thor::Base.shell = Thor::Shell::Basic
        end
        @shell = Thor::Base.shell.new
        @level = ENV['DEBUG'] ? "debug" : "info"
      end

      def info(msg, newline = nil)
        tell_stdout(msg, nil, newline) if level("info")
      end

      def confirm(msg, newline = nil)
        tell_stdout(msg, :green, newline) if level("confirm")
      end

      def warn(msg, newline = nil)
        tell_stdout(msg, :yellow, newline) if level("warn")
      end

      def error(msg, newline = nil)
        tell_stderr(msg, :red, newline) if level("error")
      end

      def debug(msg, newline = nil)
        tell_stdout(msg, nil, newline) if level("debug")
      end

      def debug?
        # needs to be false instead of nil to be newline param to other methods
        level("debug")
      end

      def quiet?
        LEVELS.index(@level) <= LEVELS.index("warn")
      end

      def ask(msg)
        @shell.ask(msg)
      end

      def level=(level)
        raise ArgumentError unless LEVELS.include?(level.to_s)
        @level = level
      end

      def level(name = nil)
        name ? LEVELS.index(name) <= LEVELS.index(@level) : @level
      end

      def trace(e, newline = nil)
        return unless debug?
        msg = "#{e.class}: #{e.message}\n#{e.backtrace.join("\n  ")}"
        tell_stdout(msg, nil, newline)
      end

      def silence
        old_level, @level = @level, "silent"
        yield
      ensure
        @level = old_level
      end

    private

      # valimism
      def tell_stdout(msg, color = nil, newline = nil)
        msg = word_wrap(msg) if newline.is_a?(Hash) && newline[:wrap]
        if newline.nil?
          @shell.say(msg, color)
        else
          @shell.say(msg, color, newline)
        end
      end

      def tell_stderr(msg, color = nil, newline = nil)
        msg = word_wrap(msg) if newline.is_a?(Hash) && newline[:wrap]
        if newline.nil?
          say_error(msg, color)
        else
          say_error(msg, color, newline)
        end
      end

      # Print to STDERR with color and formatting from Thor. This is an ugly
      # necessity that provides a feature Thor::Base.shell does not.
      def say_error(message = '', color = nil, force_new_line = (message.to_s !~ /( |\t)\Z/))
        buffer = @shell.send(:prepare_message, message, *color)
        buffer << "\n" if force_new_line && !message.end_with?("\n")

        stderr = @shell.send(:stderr)
        stderr.print(buffer)
        stderr.flush
      end

      def strip_leading_spaces(text)
        spaces = text[/\A\s+/, 0]
        spaces ? text.gsub(/#{spaces}/, '') : text
      end

      def word_wrap(text, line_width = @shell.terminal_width)
        strip_leading_spaces(text).split("\n").collect do |line|
          line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
        end * "\n"
      end
    end
  end
end
