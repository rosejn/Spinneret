require 'gosim'

class WorkloadParser < GoSim::Entity
  def initialize(filename, generators)
    super()

    @generators = generators
    def @generators.generate(sym, opts)
      return self[sym].call(opts)
    end

    @obj_map = []
    @file = File.new(filename, "r")

    @sim.schedule_event(:parse, @sid, 0, nil)
  end

  COMMENT_RE = /#.*/
  TIME_RE    = /time (\d+)/
  INST_RE    = /(\d+) (\w+)(.*)/

  def handle_parse(e)
    while(1)
      case @file.readline
      when COMMENT_RE
        next
      when TIME_RE
        @sim.schedule_event(:parse, @sid, $1.to_i - @sim.time, nil)
        break
      when INST_RE
        id = $1.to_i
        sym = $2.to_sym
        opts = $3.lstrip

        if(@generators.has_key? sym)
          @obj_map[id] = @generators.generate(sym, opts).sid
        else
          @sim.schedule_event(sym, @obj_map[id], 0, opts)
        end

      end
    end
  rescue EOFError
    printf("Workload read done...\n")
  end

end
