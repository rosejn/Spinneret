module Spinneret
  
  # A management class sitting on top of the link table.
  class LinkTable
    DEFAULT_NUM_SLOTS = 4
    DEFAULT_ADDRESS_SPACE = 10000

    def initialize(addr,
                   num_slots = nil,
                   address_space = nil,
                   distance_func = nil)

      @addr = addr
      @num_slots = num_slots || DEFAULT_NUM_SLOTS
      @address_space = address_space || DEFAULT_ADDRESS_SPACE
      @table = Array.new(log2(@address_space).ceil) { [] }

      @addr_cache = {}

      if distance_func
        @distance_func = distance_func 
      else
        @distance_func = method(:default_distance)
      end

    end
    
    # Get the node in the table which is closest to <dest_addr>.
    def closest_node(dest_addr)
      @table.flatten.min {|a, b| distance(dest_addr, a.addr) <=> distance(dest_addr, b.addr) }.addr
    end

    # Get a random node from the table.
    def random_node
      @table.flatten[rand(size)].addr
    end

    # Choose <num> random nodes from the table.  If there are not as many nodes
    # as were requested and duplicates are not allowed the response will all
    # nodes. If <allow_duplicates> is set to false then the result will not
    # contain the same node twice.
    def random_nodes(num_nodes, allow_duplicates = true)
      return @table.flatten.map {|n| n.addr} if num_nodes >= size

      nodes = []
      num_nodes.times do
        if allow_duplicates
          nodes << random_node
        else
          while(nodes.include?(node = random_node)); end
          nodes << node
        end
      end

      nodes
    end

    # The total number of nodes in the table.
    def size
      @table.flatten.size
    end

    # The distance between two network addresses.
    def distance(x, y)
      @distance_func.call(x, y)
    end
    
    # Whether the table currently contains a specific address.
    def has_addr?(addr)
      @table.flatten.find {|i| i.addr == addr} != nil
    end

    # Store an address in the table if it is new.
    # TODO: This is where policy decisions will be made about the placement
    # of nodes in the table and/or a cache etc...
    def store_addr(addr)
      return if has_addr?(addr)

      @addr_cache[addr] = true
      bin = log2(distance(@addr, addr)).floor
      @table[bin] << Peer.new(addr) if @table[bin].size < @num_slots
    end
    alias :<< :store_addr

    private

    # Log base 2
    def log2(num)
      Math.log(num) / Math.log(2)
    end

    # The default distance function is the absolute distance on the single
    # dimensional number line.
    def default_distance(x, y)
      d1 = (y - x).abs
      min = (y < x ? y : x)
      max = (y >= x ? y : x)
      d2 = (@address_space - max) + min

      return (d1 < d2 ? d1 : d2)
    end
  end

  # Just a container for keeping things like status information about a
  # specific peer in the link table.
  class Peer
    attr_reader :addr

    def initialize(addr)
      @addr = addr
    end
  end
end
