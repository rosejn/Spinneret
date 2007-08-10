module Spinneret

  class Node < GoSim::Net::RPCNode
    include GoSim::Base
    include KeywordProcessor

    include Search::DHT
    include Search::KWalker
    include Search::KWalkerSample
    include Search::JoinQuery

    attr_reader  :nid, :link_table

    # Create a new node
    # [*nid*] The unique network id for this node.
    def initialize(nid, start_peer_addr = nil, report_converge_time = false)
      super()

      @report_join = report_converge_time
      @start_peer_addr = start_peer_addr
      @config = Configuration::instance.node
      @pad = Scratchpad::instance

      analysis_setup_aspects() 

      extend(@config.maintenance_algorithm)
      extend(Maintenance::Opportunistic)
      opportunistic_setup_aspects()

      @nid = nid || @link_table.random_id
      @link_table = LinkTable.new(self)

      log {"#{@nid} - using #{@config.maintenance_algorithm.to_s}"}

      # Log
      #puts "New Node #{@nid}"
      GoSim::Data::DataSet[:node].log(:new, @nid, @addr)

      join()
      start_maintenance()
    end
      
    def analysis_setup_aspects
      insert_send_aspect do | method, outgoing |
        GoSim::Data::EventCast::instance.publish(:packet_sent, @nid, method)
        outgoing
      end
    end

    def join
      return if @start_peer_addr.nil?

      log {"#{@nid} - adding start peer #{@start_peer_addr}"}
      @start_join = @sim.time  if @report_join

      peer = @link_table.store_peer(@start_peer_addr)
      run_join_query(@nid, [peer], 0)
    end

    def stop_maintenance
      @maint_timeout.cancel
    end

    def start_maintenance
      @maint_timeout = set_timeout(@config.maintenance_rate, true) do
        status = true
        #if !@link_table.converged? 
          #puts "#{@sim.time}: #{@nid} not converged."
          status = false
          do_maintenance  
        #end
        GoSim::Data::EventCast::instance.publish(:local_converge_report, @nid, status)
      end

      if @report_join
        timeout = set_timeout(1000, true) do
          if @link_table.converged?
            time = @sim.time - @start_join
            GoSim::Data::EventCast::instance.publish(:join_time, @nid, time)
            @report_join = false
            timeout.cancel
          end
        end
      end

    end
    
    def to_s
      "nid=#{@nid} addr=#{addr} peers: #{link_table.to_s}"
    end

    def inspect
      "#<Spinneret::Node #{to_s}"
    end

    def failure(arg)
      alive(false)
      GoSim::Data::DataSet[:node].log(:failure, @nid)
      @pad.nodes.delete(self)
      @maint_timeout.cancel
      @link_table = nil
      set_timeout(10000) {
        die
      }
    end
    alias :leave :failure

    def handle_failed_packet(pkt)
      puts "Node #{nid}: got failed packet! #{pkt.inspect}"
      log {"Node #{nid}: got failed packet! #{pkt.inspect}"}
    end

    def id
      return nid
    end

  end
end
