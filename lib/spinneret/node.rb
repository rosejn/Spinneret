module Spinneret

  class Node < GoSim::Net::RPCNode
    include Base
    include KeywordProcessor

    include Search::DHT
    include Search::KWalker
    include Search::JoinQuery

    attr_reader  :nid, :link_table

    # Create a new node
    # [*nid*] The unique network id for this node.
    def initialize(nid, start_peer_addr = nil)
      super()

      @start_peer_addr = start_peer_addr
      @config = Configuration::instance.node
      @pad = Scratchpad::instance

      extend(@config.maintenance_algorithm)
      extend(Maintenance::Opportunistic)
      setup_aspects

      @nid = nid || @link_table.random_id
      @link_table = LinkTable.new(self)

      log {"#{@nid} - using #{@config.maintenance_algorithm.to_s}"}

      # Log
      #puts "New Node #{@nid}"
      GoSim::Data::DataSet[:node].log(:new, @nid, @addr)

      join()
      start_maintenance()
    end

    def join
      return if @start_peer_addr.nil?

      log {"#{@nid} - adding start peer #{@start_peer_addr}"}

      peer = @link_table.store_peer(@start_peer_addr)
      run_join_query(@nid, [peer], 0)
    end

    def stop_maintenance
      @maint_timeout.cancel
    end

    def start_maintenance
      @maint_timeout = set_timeout(@config.maintenance_rate, true) do
        status = true
        if !@link_table.converged?
          #puts "#{@sim.time}: #{@nid} not converged."
          status = false
          do_maintenance  
        end
        GoSim::Data::EventCast::instance.publish(:local_converge_report, @nid, status)
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
    end
    alias :leave :failure

    def handle_failed_packet(pkt)
      puts "Node #{nid}: got failed packet! #{pkt.inspect}"
      log {"Node #{nid}: got failed packet! #{pkt.inspect}"}
    end

    def id
      return nid
    end

    # Wrap rpc send and receive so we can count messages
    def handle_rpc_request(request)
      @pad.message_count += 1
    end

    def handle_rpc_response(response)
      @pad.message_count += 1
    end
  end
end
