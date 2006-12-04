module Spinneret

  class Node < GoSim::Net::Node
    include Base
    include KeywordProcessor

    DEFAULT_NUM_SLOTS = 4
    DEFAULT_ADDRESS_SPACE = 10000

    DEFAULT_MAINTENANCE = Maintenance::Pull

    
    attr_reader  :nid, :link_table

    # TODO: Move to keyword style hash
    def initialize(nid, args = {})
      super()

      log "Node addr: #{@addr} nid: #{nid}"

      args = params_to_ivars(args, {
        :start_peer => nil,
        :maintenance => DEFAULT_MAINTENANCE,
        :address_space => DEFAULT_ADDRESS_SPACE,
        :num_slots => DEFAULT_NUM_SLOTS,
        :distance_func => nil })

      if @distance_func.nil?
        @distance_func = DistanceFuncs.sym_circular(@address_space)
        args[:distance_func] = @distance_func
      end

      extend(@maintenance)

      @nid = nid

      # TODO: Decide on and implement the passing through of parameters down
      # to the link table: slots, address space, distance_func...
      @link_table = LinkTable.new(nid, args)
      
      if @start_peer
        #puts @start_peer.inspect, @nid

        @link_table.store_peer(@start_peer)
        do_maintenance
      end
      set_timeout(10, true) { do_maintenance }
    end

    def handle_failed_packet(pkt)
      log "#{nid} - got failed packet! #{pkt.inspect}"
    end

    def handle_search(id)

    end
  end
end
