module Spinneret

  class Analyzer < GoSim::Entity
    include Base
    include KeywordProcessor
    include Singleton

    DEFAULT_MEASUREMENT_PERIOD = 10000
    DEFAULT_STABILITY_THRESHOLD = 10
    DEFAULT_OUTPUT_PATH = 'output'

    attr_reader :graph, :measurement_period

    def initialize()
      super()

      #Register as a observer, in order to get reset messages
      @sim.add_observer(self)
      @trials = {}
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

      @trials = {}
      @convergence = Hash.new(-1)
      internal_init

      return self
    end

    def run_phase
      analyze_search
      indegree_calc
      sum_of_squares_stats
      table_sizes
      #outdegree_calc
      #is_connected?
      network_converged?

      @trials = {}
      @successful_dht_searches = 0
      @failed_dht_searches = 0
      @successful_kwalk_searches = 0
      @failed_kwalk_searches = 0
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
      # temp
      #@uids = Hash.new(0)

      @high_indegree = Hash.new(0)
      @trials = {}
      @successful_dht_searches = 0
      @failed_dht_searches = 0
      @successful_kwalk_searches = 0
      @failed_kwalk_searches = 0
      setup_rgl_graph
      set_timeout(@measurement_period, true) { run_phase }
    end


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

    public

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

      write_data_file("link_count") do |f|
        links.each {|k,v| f << "#{k} #{v}" }
      end
    end

    def handle_check_stability
      @nodes.detect(@stability_handler) do |n| 
        @stability_threshold > (@sim.time - n.link_table.last_modified)
      end
    end

    def default_stable_handler
      if network_converged?
        log "Network is stable..."  
      else
        log "Network is not stable..."
      end
    end

    def analyze_search
      append_data_file("search_success_pct") do |f|
        f.write("#{@sim.time} #{@successful_dht_searches} " +
                "#{@failed_dht_searches} #{@successful_kwalk_searches} " +
                "#{@failed_kwalk_searches}\n")
      end
    end

    # Assumes that all link tables use identical distance functions
    def network_converged?
      converged = true
      @nodes.each { | peer | converged &= node_converged?(peer) }
      return converged
    end

    def node_converged?(peer)
      return peer.link_table.chi_squared_test
    end

    def sums_of_squares
      x, y = @nodes.map do |node|
        node.link_table.sum_of_squares
      end.histogram

      write_data_file("sums_of_squares") do |f|
        x.each_with_index {|val, index| f << "#{val} #{y[index]}\n" }
      end
    end

    def sum_of_squares_stats
      mean, std = @nodes.map do |node|
        node.link_table.sum_of_squares
      end.normal_fit

      append_data_file("sum_of_squares_mean") do |f|
        f.write("#{@sim.time} #{mean} #{std}\n")
      end
    end

    def table_sizes
      table_sizes = Array.new(@nodes.first.link_table.max_peers + 1, 0)
      @nodes.each {|n| table_sizes[n.link_table.size] += 1 }

      write_data_file("table_sizes") do |f|
        table_sizes.each_with_index {|count, index| f << "#{index} #{count}\n" } 
      end
    end

    def indegree_calc
      nodes_in = Hash.new(0)
      @nodes.each do | n |
        n.link_table.each { | out_e | nodes_in[out_e.nid] += 1 }
      end

      max = nodes_in.values.max
      return  if max.nil?
  
      write_data_file("indegree_node") do |f|
        sorted = nodes_in.sort { | p1, p2 | p1[1] <=> p2[1] }
        sorted.each { | x | f.write("#{x[0]} #{x[1]}\n") }
        if sorted.length > 10
          sorted[-5..-1].each { | x | @high_indegree[x[0]] += 1 }
        end
      end

      write_data_file("high_indegree") do |f|
        @high_indegree.each { | node, times | f.write("#{node} #{times}\n") }
      end

      distrib = Array.new(max + 1, 0)
      total_in = 0
      nodes_in.each { | node, in_e | distrib[in_e] += 1; total_in += 1 }
      distrib.map! { | x | (x.nil? ? 0 : x) }

      write_data_file("indegree_dist") do |f|
        distrib.each_index do | idx | 
          f.write("#{idx} #{distrib[idx]/Float(total_in)}\n") 
        end
      end

      pts = []
      distrib.each_index { | idx | distrib[idx].times { pts << idx } }
      normal_dist = pts.normal_fit

      append_data_file("indegree_normal_mean") do |f|
        f.write("#{@sim.time} #{normal_dist[0]} #{normal_dist[1]}\n")
      end

      # Make a link to the current one for live graphing...
      cur_path = File.join(@output_path, "cur_indegree_dist")
      File.delete(cur_path) if File.symlink?(cur_path)
      File.symlink(datafile_path("indegree_dist"), cur_path)
    end

    def successful_dht_search(uid)
      #log "Recved uid #{uid} again"  if @uids[uid] == true
      #@uids[uid] = true
      @successful_dht_searches += 1
    end

    def failed_dht_search(uid)
      #log "Recved uid #{uid} again"  if @uids[uid] == true
      #@uids[uid] = true
      @failed_dht_searches += 1
    end

    def successful_kwalk_search(uid)
      #log "Recved uid #{uid} again"  if @uids[uid] == true
      #@uids[uid] = true
      @successful_kwalk_searches += 1
    end

    def failed_kwalk_search(uid)
      #log "Recved uid #{uid} again"  if @uids[uid] == true
      #@uids[uid] = true
      @failed_kwalk_searches += 1
    end

    def datafile_path(category)
      File.join(@output_path, @sim.time.to_s + '_' + category)
    end

    def write_data_file(category, &block)
      File.open(datafile_path(category), "w") do | f |
        yield(f)
      end
    end

    def append_data_file(filename, &block)
      File.open(File.join(@output_path, filename), "a") do | f |
        yield(f)
      end
    end
  end
end
