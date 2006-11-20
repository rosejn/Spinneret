class KWalker
  NUM_WALKERS = 32
  MAX_HOPS = 20

  MAX_TRIES = 5
  
  def initialize(node, k = NUM_WALKERS, ttl = MAX_HOPS)
    @node = node
    @k = k
    @ttl = ttl
  end

  def search(query)
    return start_node, 0 if keys.include?(start_node)

    table = @rt.get_node_rt(start_node)

    nodes = table.random_nodes(@k)

    results = nodes.map do |n|
      #@@logger.debug "- - - - - - - - - -"
      do_search(n, n, keys, 1)
    end

    results.min do |a,b|
      a[1] <=> b[1]
      # Sort by hops if they both found the same node.
      #if a[0] == b[0]
      #  a[1] <=> b[1]
      #else # Close doesn't mean anything so return -1
        #table.dist(a[0], key) <=> table.dist(b[0], key)
       # -1
       #end
    end
  end

  def do_search(start_node, last_node, keys, hop_count)
    #@@logger.debug("%d -> %d\n" % [last_node, start_node])
    @visited[start_node] = true

    if keys.include?(start_node) || hop_count == @ttl
      return start_node, hop_count 
    end

    table = @rt.get_node_rt(start_node)
    if @with_state
      tries = 0
      begin
        next_node = table.random_node
        tries += 1
      end until (!@visited.has_key?(next_node) || tries == MAX_TRIES); 
    else
      # Since we are a directed graph it is highly improbable we even have a
      # connection to the start_node so just grab a node and go.
      #while(start_node == (next_node = table.random_node)); end
      next_node = table.random_node
    end

    @hops += 1
    return do_search(next_node, start_node, keys, hop_count + 1)
  end
end
