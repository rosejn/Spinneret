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

      @config = Configuration.instance
      @config.analyzer.stability_handlers ||= []

      @pad = Scratchpad::instance

      ecast = GoSim::Data::EventCast.instance
      ecast.add_handler(:dht_search_begin) do | id |

      end

      ecast.add_handler(:dht_search_finish) do | id, state, hops |
        if state
          @successful_dht_searches += 1
          @dht_hops += hops
        else
          @failed_dht_searches += 1
        end
      end

      ecast.add_handler(:kwalker_search_finish) do | id, state, hops |
        if state
          @successful_kwalker_searches += 1
          @kwalker_hops += hops
        else
          @failed_kwalker_searches += 1
        end
      end

      ecast.add_handler(:local_converge_report) do | nid, status |
        @local_converged_nodes[nid] = true  if status == true
      end

      ecast.add_handler(:join_time) do | nid, time |
        append_data_file("join_time") do |f|
          f << "#{nid} #{time}\n"
        end
      end

      ecast.add_handler(:packet_sent) do | nid, method |
        @sent_packets[method] += 1
      end

      internal_init
    end

    def enable
      @timeout = set_timeout(@config.analyzer.measurement_period, true) { run_phase }

      @enabled = true
      return self
    end

    def disable
      @timeout.cancel unless @timeout.nil?
      @enabled = false
    end

    def run_phase
      network_size
      #indegree_calc
      #sum_of_squares_stats
      #table_sizes
      #outdegree_calc
      #log "Not connected!\n" if !is_connected?
      search_analysis
      packet_counts

      convergence = network_converged?
      @config.analyzer.stability_handlers.each { | h | h.call(convergence) }

      append_data_file("local_convergance") do | f |
        f << "#{@sim.time} #{@local_converged_nodes.length}\n"
      end

      @successful_dht_searches = 0
      @failed_dht_searches = 0
      @dht_hops = 0
      @successful_kwalker_searches = 0
      @failed_kwalker_searches = 0
      @kwalker_hops = 0
      @local_converged_nodes = {}
      @sent_packets.each { | key, value | @sent_packets[key] = 0 } 
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

      @successful_dht_searches = 0
      @failed_dht_searches = 0
      @dht_hops = 0
      @successful_kwalker_searches = 0
      @failed_kwalker_searches = 0
      @kwalker_hops = 0
      @local_converged_nodes = {}
      @sent_packets = Hash.new(0)
      #setup_rgl_graph
    end

    def search_analysis
      append_data_file("dht_hop_average") do | f |
        if @successful_dht_searches == 0
          avg = 0
        else
          avg = @dht_hops/@successful_dht_searches.to_f
        end
        f << "#{@sim.time} #{avg}\n"
      end

      append_data_file("kwalker_hop_average") do | f |
        if @successful_kwalker_searches == 0
          avg = 0
        else
          avg = @kwalker_hops/@successful_kwalker_searches.to_f
        end
        f << "#{@sim.time} #{avg}\n"
      end

      append_data_file("search_success_pct") do |f|
        f.write("#{@sim.time} #{@successful_dht_searches} " +
                "#{@failed_dht_searches} #{@successful_kwalker_searches} " +
                "#{@failed_kwalker_searches}\n")
      end
    end
    
    def packet_counts
      @sent_packets.each do | type, count |
        append_data_file("packet_" + type.to_s) do | f |
          f << "#{@sim.time} #{count}\n"
        end
      end
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

    def network_size
      append_data_file("network_size") do |f|
        f << "#{@sim.time} #{@pad.nodes.size}\n"
      end
    end

    def default_stable_handler
      if network_converged?
        log "Network is stable..."  
      else
        log "Network is not stable..."
      end
    end

    # Assumes that all link tables use identical distance functions
=begin
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
      
      log {"#{num_converged} nodes converged."}
      #puts "#{num_converged} nodes converged."
      GoSim::Data::DataSet[:converge_measure].log(:update, num_converged)

      return converged
    end
=end

    def network_converged?
      trials = 0
      success = 0

      100.times do
        cur_peer = @pad.nodes.rand
        search = @pad.nodes.rand
        hops = 0
        trials += 1

        while cur_peer
          lt = cur_peer.link_table
          next_peer = lt.closest_peer(search.nid)

          # Handle case where nothing is in table.
          break if next_peer.nil?

          if(lt.distance(search.nid, cur_peer.nid) <=
             lt.distance(search.nid, next_peer.nid))
            #We didn't get any closer
            success += 1 if(cur_peer.nid == search.nid)
            break
          end

          hops += 1
          cur_peer = @pad.nodes.find {|n| n.nid == next_peer.nid}

        end
      end

      GoSim::Data::DataSet[:converge_measure].log(:update, 
                                                  (trials-success)/trials)

#      error_rate = @config.link_table.max_peers / (Math.log2(@config.link_table.address_space))
      error_rate = @config.link_table.max_peers / (Math.log2(Scratchpad::instance.nodes.length))

      error_rate = 1.0 if error_rate > 1.0

      measure = (trials - success <= (1.05 - error_rate) * trials)
      append_data_file("converge_measure") do | f |
        f << "#{@sim.time} #{trials - success}"
        f << " (global converged)"   if measure
        f << "\n"
      end

      # Check for complete local convergence - there will be no improvement to
      # global convergence if this is the case.
      if measure == false
        local_converged = 0
        @pad.nodes.each do | cur_peer |
          local_converged += 1 if cur_peer.link_table.converged?
        end
        measure = (local_converged >= @pad.nodes.length * 0.98)
      end

      puts "#{trials} (#{success}) [lcl #{local_converged}] = #{measure}"

      return measure
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
