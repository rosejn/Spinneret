module Spin
  class ConvergeHandler
    include GoSim::Base

    def initialize(time)
      @converge_time = time
      @sim = GoSim::Simulation.instance
    end

    def handle
      return nil  if @converge_time == -1

      a = Spinneret::Analyzer.instance
      time = @sim.time

      if a.network_converged?
        log "Converged"
        @start ||= time
        if(time - @start  >= @converge_time)
          log "Quiting due to convergence.\n"
          @sim.stop
        end
      else
        @start = nil
      end
    end
  end

  class Simulation
    include Singleton

    def initialize
      @pad = Scratchpad::instance
      @config = Configuration::instance

      # Create data sets for collection and viz
      node_data = GoSim::DataSet.new(:node, "output")
      node_data = GoSim::DataSet.new(:link, "output")
      node_data = GoSim::DataSet.new(:dht_search, "output")

      @generators = {}
      @generators[:init] = Proc.new do | opts | 
        nid = opts.to_i
        rand_node = @pad.nodes.rand
        peer = nil
        if !rand_node.nil?
          peer = Spinneret::Peer.new(rand_node.addr, rand_node.nid) 
        end

        # Create
        @pad.nodes << Spinneret::Node.new(nid, peer)
        @pad.nodes.last
      end

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

      @config.analyzer.stability_handler = 
        Spin::ConvergeHandler.new(@converge).method(:handle)

      puts "Beginning simulation...\n"
      if(@sim_length != 0)
        GoSim::Simulation.run(@sim_length)
      elsif(@wl_settings.sim_length != 0)
        GoSim::Simulation.run(@wl_settings.sim_length.to_i)
      else
        GoSim::Simulation.run() 
      end
    end

  end  # Simulation
end  # module Spin

