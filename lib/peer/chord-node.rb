require 'chord-fingers'
require 'chord-packet'
require 'chord-constant-hash'
require 'chord-tracker'
require 'chord-settings'
require 'response-table'
require 'range-types'
require 'enumeration'
require 'math-ext'

Finger = Struct.new(:finger_id, :node)

class ChordNode < GoSim::Net::Node  # GoSim::Entity
    INVALID_NODE = nil

    #Time defines
    ONE_MINUTE = [0, 1]
    TWO_MINUTE = [0, 2]

    class InconsistantRouteState < Exception
    end

    class RebuildFingersEvent < GoSim::Event

    end

    class StartStabilizeEvent < GoSim::Event

    end

    class TimeoutEvent < GoSim::Event
        def initialize(&blk)
            super()
            
            @meth = blk
        end

        def call
            @meth.call
        end
    end

    attr_reader :addr

    class State < Enumeration
        enum :JOINING, :BUILDING_FINGERS, :INTIGRATED

        # Final state will alway be invalid
        enum :INVALID
    end

    #ignore these - special debug variables for printing
    @@last = nil
    #end ignore
    
    def initialize(node_id, tracker)
        super()

        @node_id = node_id
        @hash_id = ConstantHash.nodeid_hash(node_id)
        @addr = @sid
        @tracker_addr = tracker
        @fingers = ChordFingerTable.new(@hash_id)

        @state = State::INVALID
        @pkt_manager = ResponseTable.new(@sid)

        @sim = GoSim::Simulation.instance
        @settings = ChordSettings.instance

        @hash_objects = {}

        node_printf("New chord node %d (0x%0x), addr %d\n", @node_id, @hash_id, @addr)
    end

    def handle_timeout_event(event)
        event.call
    end

    def handle_initialize(event)
	    node_printf("Hello from initialize.\n")

        pkt = ChordTracker::BootstrapRequestPacket.new(nil, @addr, @settings.num_bootstrap_nodes)
        send_packet(@tracker_addr, pkt)
    end

    def handle_bootstrap_info_packet(pkt)
        node_printf("Bootstrap info recieved: %s\n", pkt.nodes)

        if !pkt.nodes.empty?
            @rand_node_cache = pkt.nodes
            join(@rand_node_cache[rand(@rand_node_cache.length)])
        else   # We are the first node as far as we know, set some defaults
            @successor = @self_node  # we are our own successor
            register_with_tracker()
        end
    end

    def handle_response_timeout(timeout)
        if @pkt_manager.timeout_on?(timeout)
            node_printf("Recv'ed timeout for packet %d.\n", timeout.pkt_id)
            @pkt_manager.timeout(timeout)      
        end
    end

    def handle_chord_packet(pkt)
        node_printf("Hello from handle_chord_packet, recv'ed %s\n", pkt)

        if(pkt.htl == 0)
            node_printf("Dropping packet, htl ==0\n")
            return
        end

        # First we check if this is packet we already have state for
        @pkt_manager.recv(pkt)  if @pkt_manager.waiting_on?(pkt)
        pkt.htl -= 1
    end

    def handle_rebuild_fingers_event(e)
        build_fingers()
    end
    
    def handle_start_stabilize_event(e)
        node_printf("Starting a stabilization round.\n")

        p = GetPredecessorPacket.new(nil, @addr)
        @pkt_manager.hook_packet(p) do | pkt |
            node_printf("Received predecessor response.\n")
            if(!pkt.hash_id.nil?)
                next_inter = ChordInterval.new(Interval::EXC, @hash_id, 
                                               @successor.hash_id, Interval::EXC)
                if(next_inter.include?(pkt.hash_id))
                    node_printf("\tsetting successor to node %d (addr %d)\n", pkt.node_id, pkt.addr)
                    @successor = NodeInfo.new(pkt.hash_id, pkt.node_id, pkt.addr)
                    @sim.schedule_event(@sid, 0, RebuildFingersEvent.new())
                end
            end

            notify = PredecessorNotifyPacket.new(nil, @hash_id, @node_id, @addr)
            send_packet(@successor.addr, notify)
        end

        send_packet(@successor.addr, p)

        time = @settings.time_base.unit_time(0, 0, 2)  # .5 seconds
        @sim.schedule_event(@sid, time, StartStabilizeEvent.new)
    end

    def handle_routed_packet(pkt)
        node_printf("Handling a routed packet.\n")

        if(pkt.htl == 0)
            node_printf("Dropping packet, htl ==0\n")
            return
        end

        pkt.htl -= 1
        
        print_fingers()

        if(self_interval.include?(pkt.hash_id))
            deliver_routed_packet(pkt)
        else
            next_hop = closest_preceding_node(pkt.hash_id)
            next_hop = @successor  if next_hop == @self_node

            node_printf("Forwarding a RoutedPacket to %d.\n", next_hop.node_id)
            send_packet(next_hop.addr, pkt)
        end
    end

    def handle_get_predecessor_packet(pkt)
        node_printf("Handling a predecessor request.\n")

        if !@predecessor.nil?
            node_printf("\tsending node %d (addr %d)\n", @predecessor.node_id, @predecessor.addr)
            resp = GetPredecessorResponse.new(pkt, @predecessor.hash_id,
                                              @predecessor.node_id, 
                                              @predecessor.addr)
        else
            node_printf("\tsending nil\n")
            resp = GetPredecessorResponse.new(pkt, nil, nil, nil)
        end

        send_packet(pkt.requester, resp)
    end

    def handle_predecessor_notify_packet(pkt)
        node_printf("Handling a predecessor notify.\n")

        if(!@predecessor.nil?)
            pred_inter = ChordInterval.new(Interval::EXC, @predecessor.hash_id,
                                           @hash_id, Interval::EXC)
        end

        # Ruby will check first argument first, so second statement is safe
        if(@predecessor.nil? || pred_inter.include?(pkt.hash_id))
            node_printf("\tsetting predecessor to node %d, was %s\n",
                        pkt.node_id, @predecessor.nil? ? "nil" : @predecessor.node_id)
            @predecessor = NodeInfo.new(pkt.hash_id, pkt.node_id, pkt.addr)
        end
    end

    def handle_find_successor_packet(pkt)
        node_printf("Node %d: handle_find_successor_packet(), %#x\n", @node_id, pkt.hash_id)

        if(pkt.htl == 0)
            node_printf("Dropping packet, htl ==0\n")
            return
        end

        skip_route = false
        begin
            next_hop = closest_preceding_node(pkt.hash_id)
        rescue InconsistantRouteState then
            return
            ######  Renable latter for more detailed error handleing - for now drop on floor and wait for retry
           # p = RetryLookup.new(pkt, @node_id, @addr, InconsistantRouteState)
           # send_packet(pkt.requester, p)
           # skip_route = true
        end
            
        if(!skip_route)
            if(next_hop == @self_node)
                # Return successor to requester
                node_printf("\tsending response to addr %d: succ is %d\n", pkt.requester, @node_id)
                p = FindSuccessorResponse.new(pkt, @hash_id, @node_id, @addr)
                send_packet(pkt.requester, p)
            else
                # Forward the same packet again, to the next search node
                node_printf("\tforwarding onward to node %d.\n", next_hop.node_id)
                pkt.htl -= 1
                send_packet(next_hop.addr, pkt)
            end
        end

        # Special "bootstrap node" condition
        if(@successor == @self_node)
            @successor = NodeInfo.new(pkt.hash_id, -1, pkt.requester)
            @sim.schedule_event(@sid, 0, RebuildFingersEvent.new())
            node_printf("\tAdding call back to set fingers.  Succ hash 0x%x.\n",
                        @successor.hash_id)

            # Start the fixup algorithm, fast for the first time
            time = @settings.time_base.unit_time(0, 0, 1)  # 1 second
            @sim.schedule_event(@sid, time, StartStabilizeEvent.new)
        end
    end

    def closest_preceding_node(hash_id)
        return @self_node  if self_interval.include?(hash_id)

        pred = @fingers.predecessor(hash_id)

        # Need to return "self" here
        if pred.nil?  # None of the fingers have it, nor do we, error
            node_printf("Invalid hash_id.  Dumping fingers/info and quiting.\n")
            #printf("%s\n", self.to_str())
            #@fingers.print_table()
            exit(1)
        end

        # Wrap around case
        if pred.node_id == @node_id
            raise InconsistantRouteState
        end

        return pred
    end

    def join(bootstrap_node)
        @state = State::JOINING
        @predecessor = INVALID_NODE

        node_printf("Starting join process.\n")

        p = FindSuccessorPacket.new(nil, @hash_id, @addr)
        time_out = @settings.time_base.unit_time(0, 0, 5) #5 seconds
        @pkt_manager.hook_packet(p) do | pkt | 
            if(pkt.class == RetryLookup)
                to = TimeoutEvent.new() { join(bootstrap_node) }
                time = @settings.time_base.unit_time(0, 0, 5)
                @sim.schedule_event(@sid, time, to) 
            else
                finish_join(pkt) 
            end
        end
        @pkt_manager.hook_timeout(p, time_out) { join(bootstrap_node) }
        s = send_packet(bootstrap_node.addr, p)
    end

    def finish_join(r_pkt)
        node = NodeInfo.new(r_pkt.hash_id, r_pkt.node_id, r_pkt.addr)
        build_fingers(node)
        @successor = node

        # Start the fixup algorithm, fast for the first time
        time = @settings.time_base.unit_time(0, 0, 1)  # 5 seconds
        @sim.schedule_event(@sid, time, StartStabilizeEvent.new)
    end

    def build_fingers(successor = @successor)
        @state = State::BUILDING_FINGERS

        # Now lets send out parellel requests for the fingers.
        #
        # Find the first non-trival finger and assign trival fingers
        node_printf("(0x%x - \n\t0x%x) mod hash_size =\n\t0x%x\n", successor.hash_id, 
                    @hash_id, (successor.hash_id - @hash_id) % @settings.max_hash_value)

        i = Math.log2((successor.hash_id - @hash_id) % @settings.max_hash_value).ceil
        node_printf("\ttrival fingers: %d -> %d\n", 0, i)
        @fingers.trival_fingers(i - 1, successor)

        if(i < @fingers.num_fingers) 
            (i...@fingers.num_fingers).each { | x | build_finger(x, successor) }
        end

        time = @settings.time_base.unit_time(0, 5, 0)  # 5 minutes
        @sim.schedule_event(@sid, time, RebuildFingersEvent.new())
    end

    def to_str
        str = sprintf("%4d %4d %#042x ", @node_id, @addr, @hash_id)
        if @predecessor.nil?
            str += sprintf(" nil ( nil) ")
        else
            str += sprintf("%4d (%4d) ", @predecessor.node_id, @predecessor.addr)
        end

        if @successor.nil?
            str += sprintf(" nil ( nil)")
        else
            str += sprintf("%4d (%4d)", @successor.node_id, @successor.addr)
        end

        return str
    end

    def print_fingers()
        @fingers.print_table()
    end

    def print_fingers_cond()
        if @fingers.print_needed
            printf("fup %d %d %#042x\n", @sim.time, @node_id, @hash_id)
            print_fingers()
            printf("=\n")
        end
    end

    private

    def self_interval
        ## Pretty sure this should be *my* hash space, not my successor
        # succ_space = ChordInterval.new(Interval::EXC, @hash_id, 
        #                               @successor.hash_id, Interval::INC) 
        end_type = Interval::EXC
        if(!@predecessor.nil?)
            first_id = @predecessor.hash_id
        else
            first_id = @hash_id
            end_type = Interval::INC
        end
        return ChordInterval.new(Interval::EXC, first_id, @hash_id, end_type)
    end

    def self_node
        return NodeInfo.new(@hash_id, @node_id, @addr)
    end

    def deliver_routed_packet(pkt)
        node_printf("Delivering RoutedPacket, hash_id %#x.\n", pkt.hash_id)
        case pkt
            when InsertPacket:
                node_printf("Insertion performed.\n")
            when SearchPacket:
                node_printf("Search returning.\n")
        end
    end

    def build_finger(i_th, successor)
        finger_hash = @fingers.ideal_hash_id(i_th)
        node_printf("sending mesg to build %dth finger, 0x%x\n", i_th, finger_hash)
        time_out = @settings.time_base.unit_time(*ONE_MINUTE) #0, 1

        p = FindSuccessorPacket.new(nil, finger_hash, addr)
        @pkt_manager.hook_packet(p) do | pkt | 
            if(pkt.class == RetryLookup)
                to = TimeoutEvent.new() { build_finger(i_th, @successor) }
                time = @settings.time_base.unit_time(0, 0, 1)
                @sim.schedule_event(@sid, time, to) 
            else
                node_printf("Building finger %d -> %d (addr %d)\n", i_th, pkt.node_id, pkt.addr)
                @fingers[i_th] = NodeInfo.new(pkt.hash_id, pkt.node_id, pkt.addr)
            end
        end

        @pkt_manager.hook_timeout(p, time_out) do
            # This should try with a new successor address to prevent overload
            # (and therefore timeouts), but this is technicaly correct
            build_finger(i_th, @successor) 
        end

        s = send_packet(successor.addr, p)
    end
    
    def register_with_tracker()
        pkt = ChordTracker::RegisterPacket.new(nil, @node_id, @addr)
        send_packet(@tracker_addr, pkt)
    end

    def node_printf(format, *args)
        sim = GoSim::Simulation.instance

        #printf("\nNode %d:\n", @node_id)  if @@last != @node_id
        #printf("  @%d: " + format, sim.time, *args)
        @@last = @node_id
    end
end
