require 'zlib'

class WorkloadParser < GoSim::Entity
  def initialize(filename, generators, id_map = {})
    super()

    @generators = generators
    def @generators.generate(sym, opts)
      return self[sym].call(opts)
    end

    @obj_map = id_map
    @settings = {}
    #@file = File.new(filename, "r")
    @file = Zlib::GzipReader.open(filename)

    #@sim.schedule_event(:parse, @sid, 0, nil)
    parse(nil)  # parse up to first time event
  end

  COMMENT_RE = /#(.*)/
  SETTING_RE = /([\w\-\?!]+): (.*)/
  TIME_RE    = /time (\d+)/
  INST_RE    = /(\d+) (\w+)(.*)/

  def parse(e)
    while(1)
      case @file.readline
      when COMMENT_RE
        if SETTING_RE =~ $1
          @settings[$1] = $2
        end
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

  def method_missing(name)
    return @settings[name.to_s]
  end
end
