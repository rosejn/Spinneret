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
        @command = opt
      end
    end

    def run
      `#{@command}`
    end

    def runnable?
      return !@command.nil?
    end
  end

end
end
