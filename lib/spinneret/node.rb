module Spinneret

  class Node < GoSim::Net::Node
    include Base
    include KeywordProcessor

    include Search::DHT
    include Search::KWalker

    attr_reader  :nid, :link_table

    # Create a new node
    # [*nid*] The unique network id for this node.
    def initialize(nid, start_peer_addr = nil)
      super()

      @start_peer_addr = start_peer_addr
      @config = Configuration::instance.node

      extend(@config.maintenance_algorithm)

      @link_table = LinkTable.new(self)
      @nid = nid || @link_table.nid

      # Log
      GoSim::Data::DataSet[:node].log(:new, @nid, @addr)
      
      if @start_peer_addr
        @link_table.store_peer(@start_peer_addr)
        do_maintenance
      end

      start_maintenance
    end

    def stop_maintenance
      @maint_timeout.cancel
    end

    def start_maintenance
      @maint_timeout = set_timeout(@config.maintenance_rate, true) { do_maintenance }
    end
    
    def to_s
      "nid=#{@nid} addr=#{addr} peers: #{link_table.to_s}"
    end

    def inspect
      "#<Spinneret::Node #{to_s}"
    end

    def handle_failed_packet(pkt)
      log {"Node #{nid}: got failed packet! #{pkt.inspect}"}
    end
  end
end
