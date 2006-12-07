module Spinneret

  class Analyzer < GoSim::Entity
    include Base
    include KeywordProcessor
    include Singleton

    DEFAULT_MEASUREMENT_PERIOD = 10000
    DEFAULT_STABILITY_THRESHOLD = 10
    DEFAULT_OUTPUT_PATH = 'output'

    attr_reader :graph
    attr_accessor :successes, :trials

    def initialize()
      super()

      #Register as a observer, in order to get reset messages
      @sim.add_observer(self)
    end

    def setup(nodes, args = {})
      params_to_ivars(args, {
                     :address_space => Node::DEFAULT_ADDRESS_SPACE,
                     :output_path => DEFAULT_OUTPUT_PATH,
                     :measurement_period => DEFAULT_MEASUREMENT_PERIOD,
                     :stability_threshold => DEFAULT_STABILITY_THRESHOLD,
                     :stability_handler => method(:default_stable_handler) 
      })

      @nodes = nodes

      internal_init

      return self
    end

    def run_phase
      analize_search; indegree_calc; outdegree_calc; is_connected?

      @successes = 0
      @trials = 0
    end

    #What happens to @nodes here?  For now the reference better remain the
    #same, which isn't an issue, as this is only used in unit testing...anyway,
    #added @nodes to attr_writer
    def update
      log "Resetting Analyzer"
      reset
      internal_init
      log "Analyzer now has sid #{sid}"
    end

    private

    def internal_init
      @high_indegree = Hash.new(0)
      @successes = 0
      @trials = 0
      setup_rgl_graph
      set_timeout(@measurement_period, true) { run_phase }
    end

    public

    def setup_rgl_graph
      require 'rgl/base'
      require 'rgl/implicit'
      require 'rgl/connected_components'

      @node_hash = {}

      @graph = RGL::ImplicitGraph.new do |g|
          g.vertex_iterator { |block|
            @nodes.each {|n| block.call(n) }
          }

          g.adjacent_iterator { |node, block|
            node.link_table.peers.each do |peer|
              block.call(@node_hash[peer.nid])
            end
          }

          g.directed = true
      end
    end

    def is_connected?
      connected_components == 1
    end

    def connected_components
      @nodes.each {|n| @node_hash[n.nid] = n }
      @graph.strongly_connected_components.num_comp
    end

    def handle_link_count
      links = {}

      @nodes.each do |n| 
        l = n.size
        links.has_key?(l) ? links[l] += 1 : links[l] = 1
      end

      File.open(File.join(output_path, @sim.time, '_link_count')) do |f|
        links.each {|k,v| f << "#{k} #{v}" }
      end
    end

    def handle_check_stability
      @nodes.detect(@stability_handler) do |n| 
        @stability_threshold > (@sim.time - n.link_table.last_modified)
      end
    end

    def default_stable_handler
      log "Network is stable..."
    end

    def handle_bin_distribution
      raise "Must specify an ideal_distribution to do the bin distribution analysis." unless @ideal_distribution 

      distances = {}

      @nodes.each do |n| 
        n.link_table.bin_sizes
        l = n.size
        links.has_key?(l) ? links[l] += 1 : links[l] = 1
      end

      File.open(File.join(output_path, @sim.time, '_link_count')) do |f|
        links.each {|k,v| f << "#{k} #{v}" }
      end
    end

    def analize_search
      File.open(File.join(@output_path, "search_success_pct"), "a") do | f |
        f.write("#{@sim.time} #{@successes} #{@trials-@successes} #{@trials}\n")
      end
    end

    def chi_squared_distance(observed, expected)
      sum = 0
      observed.each_with_index do |o, i| 
        sum += (o - expected[i])**2 / expected[i]
      end

      return sum
    end

    def outdegree_calc
      # The bin size needs to be parameterized correctly
      ideal_binning = calc_ideal_binning(@nodes.length, @address_space, 4)
      dist = []
      @nodes.each do | n |
        bins_size = Array.new(Math.log2(@address_space).ceil, 0.0)
        i = 0
        n.link_table.each_bin do | bin |
          bins_size[i] = bin.size.to_f
          i += 1
        end
        dist << chi_squared_distance(bins_size, ideal_binning)
      end

      bin_size, min, bins = dist.bin
      File.open(File.join(@output_path, @sim.time.to_s + "_bins_chi_dist"), "w") do | f |
        bins.each_index do | idx | 
          f.write("#{min + (idx + 0.5) * bin_size} #{bins[idx]}\n")
        end
      end
    end
      
    def calc_ideal_binning(num_nodes, addr_space, bin_size)
      density = num_nodes.to_f/addr_space.to_f
      table = Array.new(Math.log2(addr_space).ceil)
      table.each_index do | bin |
        table[bin] = density * (2**(bin+1) - 2**bin)
        table[bin] = bin_size  if table[bin] > bin_size
      end

      return table
    end

    def indegree_calc
      nodes_in = Hash.new(0)
      @nodes.each do | n |
        n.link_table.each { | out_e | nodes_in[out_e.nid] += 1 }
      end

      max = nodes_in.values.max
      return  if max.nil?
  
      File.open(File.join(@output_path, @sim.time.to_s + "_indegree_node"), "w") do | f |
        sorted = nodes_in.sort { | p1, p2 | p1[1] <=> p2[1] }
        sorted.each { | x | f.write("#{x[0]} #{x[1]}\n") }
        if sorted.length > 10
          sorted[-5..-1].each { | x | @high_indegree[x[0]] += 1 }
        end
      end

      File.open(File.join(@output_path, @sim.time.to_s + "_high_indegree"), "w") do | f |
        @high_indegree.each { | node, times | f.write("#{node} #{times}\n") }
      end

      distrib = Array.new(max + 1, 0)
      total_in = 0
      nodes_in.each { | node, in_e | distrib[in_e] += 1; total_in += 1 }
      distrib.map! { | x | (x.nil? ? 0 : x) }

      name = @sim.time.to_s + "_indegree_dist"
      File.open(File.join(@output_path, name), "w") do | f |
        distrib.each_index do | idx | 
          f.write("#{idx} #{distrib[idx]/Float(total_in)}\n") 
        end
      end

      pts = []
      distrib.each_index { | idx | distrib[idx].times { pts << idx } }
      normal_dist = normal_fit(pts)
      File.open(File.join(@output_path, "indegree_normal_mean"), "a") do | f |
        f.write("#{@sim.time} #{normal_dist[0]}\n")
      end

      # Make a link to the current one for live graphing...
      cur_path = File.join(@output_path, "cur_indegree_dist")
      File.delete(cur_path) if File.symlink?(cur_path)
      File.symlink(name, cur_path)
    end

    def normal_fit(data)
      v = GSL::Vector.alloc(data)
      return [GSL::Stats::mean(v), GSL::Stats::sd(v)]
    end
  end

end
