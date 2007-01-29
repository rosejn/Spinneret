module Spinneret

  class ResponseTable
    ResponseTimeout = Struct.new(:pkt_id)

    def initialize(sid)
      @waits = { }
      @timeouts = { }
      @sim = GoSim::Simulation.instance
      @sid = sid
    end

    def hook_packet(p, &blk)
      @waits[p.pkt_id] = blk
    end

    def unhook_packet(p)
      @waits.delete(p.pkt_id)
    end

    def hook_timeout(p, timeout, &blk)
      @timeouts[p.pkt_id] = blk
      @sim.schedule_event(@sid, timeout, ResponseTimeout.new(p.pkt_id))
    end

    def unhook_timeout(p)
      @timeouts.delete(p.pkt_id)
    end

    def timeout(p)
      meth = @timeouts.fetch(p.pkt_id, nil)
      meth.call()  unless meth.nil?
      unhook_timeout(p)
    end

    def recv(p)
      meth = @waits.fetch(p.ack_id, nil)
      meth.call(p)  unless meth.nil?
      unhook_packet(p)
      unhook_timeout_ack(p)
    end

    def waiting_on?(p)
      #        printf("\twaiting_on?(%d): %s\n", p.ack_id, @waits.has_key?(p.ack_id))
      return @waits.has_key?(p.ack_id)
    end

    def timeout_on?(timeout)
      #        printf("\ttimeout_on?(%d): %s\n", timeout.pkt_id, 
      #               @timeouts.has_key?(timeout.pkt_id))
      return @timeouts.has_key?(timeout.pkt_id)
    end

    private

    def unhook_timeout_ack(pkt)
      @timeouts.delete(pkt.ack_id)
    end
  end
