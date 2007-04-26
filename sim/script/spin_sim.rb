module Spin
  class ConvergeHandler
    include GoSim::Base

    def initialize(time)
      @converge_time = time
      @sim = GoSim::Simulation.instance
    end

    def handle(state)
      return if @converge_time < 0

      a = Spinneret::Analyzer.instance

      time = @sim.time

      if state
        log "Converged"
        @start ||= time
        if(time - @start  >= @converge_time)
          puts "Quiting due to convergence.\n"
          puts "-------------------------------------------"
          @sim.stop
          exit(0)
        end
      else
        @start = nil
      end
    end
  end

  class SearchConvergeHandler
    def initialize(wl)
      @wl = wl
      @sim = GoSim::Simulation.instance
    end

    def handle(state)
      puts "#{@sim.time} converged? #{state}"

      if state
        @wl.unpause()
      end
    end
  end

  class SimKiller < GoSim::Entity
    def initialize(time)
      super()

      puts "New sim killer, time #{time}"

      @sim.schedule_event(:kill, @sid, time, nil)
    end

    def kill(arg)
      log "Quiting due to kill instruction.\n"
      @sim.stop
      exit(0)
    end
  end

  class Simulation
    include Singleton

    def initialize
      @pad = Scratchpad::instance
      @config = Configuration::instance
      @wl_settings = nil

      # Create data sets for collection and viz
      GoSim::Data::DataSet.new(:node)
      GoSim::Data::DataSet.new(:link)
      GoSim::Data::DataSet.new(:dht_search)
      GoSim::Data::DataSet.new(:converge_measure)
      GoSim::Data::DataSetWriter.instance.set_output_file("trace.gz")
      GoSim::Data::DataSetWriter.instance.add_view_mod("spin_viz")

      @generators = {}
      @generators[:init] = WorkloadGenerator.new(nil, true, Proc.new do | opts | 
        if(opts.include? ",")
          nid, record_join_time = opts.split(",")
          nid = nid.strip
          record_join_time = record_join_time.strip
          if record_join_time == "false"
            record_join_time = false
          elsif record_join_time == "true"
            record_join_time = true
          end
        else
          nid = opts
          record_join_time = false
        end
        nid = nid.to_i

        rand_node = @pad.nodes.rand
        peer_addr = nil
        if !rand_node.nil?
          peer_addr = rand_node.addr
        end

        # Create
        @pad.nodes << Spinneret::Node.new(nid, peer_addr, record_join_time)
        @pad.nodes.last
      end)

      @generators[:converge] = WorkloadGenerator.new(/converge/, false, Proc.new do
        @wl_settings.pause()
        if @handler.nil?
          @handler = SearchConvergeHandler.new(@wl_settings).method(:handle)
          @config.analyzer.stability_handlers << @handler
        end
      end)

      @generators[:flush] = WorkloadGenerator.new(/flush (\d+)/, false, 
                                                  Proc.new do | opts |
        time = opts.to_i
        SimKiller.new(time)
      end)

      @running = false
    end

    def setup(workload, length = 0, converge = -1)
      @workload = workload
      @sim_length = length
      @converge = converge

      reset if not @running
    end

    def reset
      @running = false

      @pad.nodes = []

      if @workload
        @wl_settings = WorkloadParser.new(@workload, @generators)
        @config.link_table.address_space = @wl_settings.addr_space.to_i
        @config.link_table.distance_func = 
          DistanceFuncs::sym_circular(@config.link_table.address_space)
      end
    end

    def run
      return if @running
      @running = true

      @config.analyzer.stability_handlers << ConvergeHandler.new(@converge).method(:handle)

      puts "Beginning simulation...\n"
      if(@sim_length != 0)
        GoSim::Simulation.run(@sim_length)
      elsif(!@config.lenght.nil? && @config.length != 0)
        GoSim::Simulation.run(@config.length)
      elsif(@wl_settings.sim_length.to_i != 0 && @wl_settings.flush_end.to_i < 0)
        GoSim::Simulation.run(@wl_settings.sim_length.to_i)
      else
        GoSim::Simulation.run() 
      end
    end

  end  # Simulation
end  # module Spin

