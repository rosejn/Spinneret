require 'zlib'

WorkloadGenerator = Struct.new("WorkloadGenerator", :re, :needs_map, :method)

class WorkloadParser < GoSim::Entity
  def initialize(filename, generators, id_map = {})
    super()

    @generators = generators
    @obj_map = id_map

    @settings = {}
    #@file = File.new(filename, "r")
    @file = Zlib::GzipReader.open(filename)

    @time_offset = 0
    @paused = false

    #@sim.schedule_event(:parse, @sid, 0, nil)
    parse(nil)  # parse up to first time event
  end

  COMMENT_RE = /#(.*)/
  SETTING_RE = /([\w\-\?!]+): (.*)/
  TIME_RE    = /time (\d+)/
  INST_RE    = /(\d+) (\w+)(.*)/

  def pause
    @paused = true
    @paused_time = @sim.time
  end

  def unpause
    if @paused == true
      @paused = false
      @time_offset += @sim.time - @paused_time
      @sim.schedule_event(:parse, @sid, 0, nil)
    end
  end

  def parse(e)
    while(true)
      break if @paused

      line = @file.readline
      case line
      when COMMENT_RE
        if SETTING_RE =~ $1
          @settings[$1] = $2
        end
      when TIME_RE
        offset = ($1.to_i + @time_offset) - @sim.time
        @sim.schedule_event(:parse, @sid, offset, nil)
        break
      when INST_RE
        id = $1.to_i
        sym = $2.to_sym
        opts = $3.lstrip

        if @generators.has_key?(sym)
          generate(sym, opts)
        else
          @sim.schedule_event(sym, @obj_map[id], 0, opts)
        end
      else
        @generators.each do | key, g | 
          generate(key, $+) if g.re =~ line
        end
      end  # case

    end
  rescue EOFError
    printf("Workload read done...\n")
  end

  def generate(key, args_str)
      g = @generators[key]
      obj = g.method.call(args_str) 
      @obj_map[obj.id] = obj.sid if g.needs_map
  end

  def method_missing(name)
    return @settings[name.to_s]
  end
end
