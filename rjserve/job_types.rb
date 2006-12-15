module RJServe
module Jobs

  class ShellExecute
    def initialize
      @command = nil
    end

    def parse_opt(opt, arg)
      case opt
      when '-jh'
        puts """ -jh                     Prints this help.
 -jc  <command_str>      An escaped version of the command string."""
      when '-jc'
        @command = arg
      end
    end

    def run
      `#{@command}`
    end

    def options
      return GetoptlOng
    end

    def runnable?
      return !@command.nil?
    end

    def to_s
      return "SE: #{@command}"
    end
  end

end
end
