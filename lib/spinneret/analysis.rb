module Spinneret

  class Analyzer < GoSim::Entity
    include Base
    include KeywordProcessor
    include Singleton

    attr_reader :graph

    def initialize()
      super()

      #Register as a observer, in order to get reset messages
      @sim.add_observer(self)
      @trials = {}

      @config = Configuration.instance
      @pad = Scratchpad::instance

      internal_init
    end

    def enable
      @config.analyzer.stability_handler ||= method(:default_stable_handler) 

      @trials = {}
      @convergence = Hash.new([])

      @timeout = set_timeout(@config.analyzer.measurement_period, true) { run_phase }

      @enabled = true
      return self
    end

    def disable
      @timeout.cancel unless @timeout.nil?
      @enabled = false
    end

    def run_phase
      analyze_search
      indegree_calc
      #sum_of_squares_stats
      #table_sizes
      #outdegree_calc
      #log "Not connected!\n" if !is_connected?
      #network_converged?

      @config.analyzer.stability_handler.call()

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
      reset
      internal_init
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
    end

    def setup_rgl_graph
      require 'rgl/base'
      require 'rgl/implicit'
      require 'rgl/connected_components'

      @node_hash = {}

      @graph = RGL::ImplicitGraph.new do |g|
          g.vertex_iterator { |block|
            @pad.nodes.each {|n| block.call(n) }
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
      connected_components() == 1
    end

    def connected_components
      @pad.nodes.each {|n| @node_hash[n.nid] = n }
      @graph.strongly_connected_components.num_comp
    end

    def handle_link_count
      links = {}

      @pad.nodes.each do |n| 
        l = n.size
        links.has_key?(l) ? links[l] += 1 : links[l] = 1
      end

      write_data_file("link_count") do |f|
        links.each {|k,v| f << "#{k} #{v}" }
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
      num_converged = 0
      converged = true
      @pad.nodes.each do | peer | 
        if node_converged?(peer)
          num_converged += 1
        else
          converged = false
        end
      end
      
      #log {"#{num_converged} nodes converged."}
      puts "#{num_converged} nodes converged."

      return converged
    end

    def nodes_alive
      @pad.nodes.find_all { | node | node.alive? }.length
    end

    def node_converged?(peer)
      c_bar = Math.log2(@config.link_table.address_space / nodes_alive) 
      m_bar = (Math.log2(@config.link_table.address_space) - c_bar) / @config.link_table.max_peers

      norm = peer.link_table.normal_fit()

#      log "ideal m: #{m_bar}, real m: #{norm[0]} (std = #{norm[1]})"
      err = 1.0 - @config.link_table.max_peers / nodes_alive
      err = 0.1  if err < 0.1
      conv = norm[0].deltafrom(m_bar, err) && norm[1] < (1.1 + err) && 
        peer.link_table.size == @config.link_table.max_peers

      if !conv && peer.link_table.size == @config.link_table.max_peers
        # Only print if the table it full - if not, we don't really care
        log "Node #{peer.nid} not converged with m #{norm[0]}, std #{norm[1]}."
      end

      append_data_file("converge_measure") do | f |
        f << "#{@sim.time} #{peer.nid} #{norm[0]} #{norm[1]}"
        f << " (converged)"   if conv
        f << "\n"
      end

      return conv
    end

    def sums_of_squares
      x, y = @pad.nodes.map do |node|
        node.link_table.sum_of_squares
      end.histogram

      write_data_file("sums_of_squares") do |f|
        x.each_with_index {|val, index| f << "#{val} #{y[index]}\n" }
      end
    end

    def sum_of_squares_stats
      mean, std = @pad.nodes.map do |node|
        node.link_table.sum_of_squares
      end.normal_fit

      append_data_file("sum_of_squares_mean") do |f|
        f.write("#{@sim.time} #{mean} #{std}\n")
      end
    end

    def table_sizes
      table_sizes = Array.new(@pad.nodes.first.link_table.max_peers + 1, 0)
      @pad.nodes.each {|n| table_sizes[n.link_table.size] += 1 }

      write_data_file("table_sizes") do |f|
        table_sizes.each_with_index {|count, index| f << "#{index} #{count}\n" } 
      end
    end

    def indegree_calc
      nodes_in = Hash.new(0)
      endpoints = Hash.new { | hash, key | hash[key] = [] }
      @pad.nodes.each do | n |
        # count in edges
        n.link_table.each do | out_e | 
          nodes_in[out_e.nid] += 1 
          endpoints[out_e.nid] << n.nid
        end
      end

      write_data_file("endpoint_map") do | f |
        endpoints.each_pair { | nid, edges | f << "#{nid}: #{edges.join(", ")}\n" }
      end

      max = nodes_in.values.max
      return  if max.nil?
  
      write_data_file("indegree_node") do |f|
        sorted = nodes_in.sort { | p1, p2 | p1[1] <=> p2[1] }
        sorted.each { | x | f.write("#{x[0]} #{x[1]}\n") }
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
      cur_path = File.join(@config.analyzer.output_path, "cur_indegree_dist")
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
      File.join(@config.analyzer.output_path, @sim.time.to_s + '_' + category)
    end

    def write_data_file(category, &block)
      File.open(datafile_path(category), "w") do | f |
        yield(f)
      end
    end

    def append_data_file(filename, &block)
      File.open(File.join(@config.analyzer.output_path, filename), "a") do | f |
        yield(f)
      end
    end
  end
end
