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

    def runnable?
      return !@command.nil?
    end

    def to_s
      return "SE: #{@command}"
    end
  end

  class JobChain
    def initialize(jobs = nil)
      @job_chain = jobs || []
    end

    def add_job(job)
      @job_chain << job
    end
    alias_method :<<, :add_job

    def run
      while !@job_chain.empty?
        job = @job_chain.shift
        pid = fork { job.run }
        Process.wait(pid)
      end
    end

    def runnable?
      return !@job_chain.nil? &&
        @job_chain.inject(true) { | runnable, j | runnable && j.runnable? }
    end

    def to_s
      return "JC: " + @job_chain.join { | j | (j.to_s + "; ") }
    end
  end
end
end
