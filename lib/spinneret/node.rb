module Spinneret

  class Node < GoSim::Net::Node
    include Base
    include KeywordProcessor

    include Search::DHT
    include Search::KWalker

    #DEFAULT_MAINTENANCE = Maintenance::Pull
    #DEFAULT_MAINTENANCE = Maintenance::Push
    DEFAULT_MAINTENANCE = Maintenance::PushPull
    DEFAULT_MAINTENANCE_SIZE = 5
    DEFAULT_MAINTENANCE_PERIOD  = 1000
    DEFAULT_TABLE_SIZE = LinkTable::DEFAULT_MAX_PEERS
    
    attr_reader  :nid, :link_table

    # TODO: Move to keyword style hash
    def initialize(nid, args = {})
      super()

      #log "Node addr: #{@addr} nid: #{nid}"

      args = params_to_ivars(args, {
        :start_peer => nil,
        :maintenance => DEFAULT_MAINTENANCE,
        :maintenance_size => DEFAULT_MAINTENANCE_SIZE,
        :maintenance_rate => DEFAULT_MAINTENANCE_PERIOD })

      extend(@maintenance)

      @link_table = LinkTable.new(nid, args)
      @nid = nid || @link_table.nid
      
      if @start_peer
        @link_table.store_peer(@start_peer)
        do_maintenance
      end

      start_maintenance

      #verbose
    end

    def stop_maintenance
      @maint_timeout.cancel
    end

    def start_maintenance
      @maint_timeout = set_timeout(@maintenance_rate, true) { do_maintenance }
    end
    
    def to_s
      "nid=#{@nid} addr=#{addr} peers: #{link_table.to_s}"
    end

    def inspect
      "#<Spinneret::Node #{to_s}"
    end

    def handle_failed_packet(pkt)
      log "#{nid} - got failed packet! #{pkt.inspect}"
    end

    def handle_failure(e)
      log "Node #{nid} failed!"
      self.alive = false
    end
  end
end
