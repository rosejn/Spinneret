require 'util'

LOGBASE = 2

class LogRandRouteTable
  def initialize(node_id, buckets, dist)
    @buckets = buckets
    @node_id = node_id
    if !dist.nil?
      @dist = dist 
    else
      @dist = Proc.new { | x, y | builtin_dist(x, y) }
    end
  end

  def size
    @buckets.flatten.size
  end

  def dist(x, y)
    @dist.call(x, y)
  end

  # Get a random node from the table.
  def random_node(d = 0)
    if d.class == Range
      pool = bucket(d).flatten
      return pool[rand(pool.length)]
    else
      if(d == 0)
        bucket = @buckets.flatten
      else
        bucket = @buckets[Math.log_n(d, LOGBASE)]
      end
      return bucket[rand(bucket.length)]
    end
  end

  # Choose <num> random nodes from the table.
  def random_nodes(num, allow_duplicates = true)
    if num > @buckets.flatten.size and not allow_duplicates
      raise ArgumentError, "Table not large enough to return #{num} nodes", caller
    end

    nodes = []
    num.times do
      if allow_duplicates
        nodes << random_node
      else
        while(nodes.include?(node = random_node)); end
        nodes << node
      end
    end

    nodes
  end

  # Get the node in the table which is closest to <dest_addr>.
  def closest_node(dest_addr)
    @buckets.flatten.min do | a, b |
      a_dist = dist(dest_addr, a)
      b_dist = dist(dest_addr, b)
      a_dist <=> b_dist
    end
  end

  # Get an array of nodes in the same bucket as <dist>
  def bucket(dist)
    if dist.class == Range
      rng = (Math.log_n(dist.begin, LOGBASE)..Math.log_n(dist.end, LOGBASE))
      return @buckets[rng]
    else
      return @buckets[Math.log_n(dist, LOGBASE)]
    end
  end

  def pred()
    @buckets.flatten.each { | x | return x if(x < @node_id) }
    return -1
  end

  def succ()
    @buckets.flatten.each { | x | return x if(x > @node_id) }
    return -1
  end

  def print
    printf("%d:%s\n", @node_id, @buckets.map { | b | "[#{b.join(',')}]" })
  end

  private

  def builtin_dist(p1, p2)
    return (p2 - p1).abs
  end
end

class LogRandRouteTableParser
  def initialize(src, bucket_refine, dist = nil)
    load_graph(src, bucket_refine)
    @dist = dist
  end

  def get_nodes()
    return @network.keys
  end

  def get_node_rt(node_id)
    return LogRandRouteTable.new(node_id, @network[node_id], @dist)
  end

  private

  def load_graph(src, refine)
    @network = {}

    src.each do |line|
      line[/([0-9]+):(.*)/]
      id = Integer($1)
      bin_str = $2

      bins = bin_str.scan(/\[(.*?)\]/).collect {|bin| bin.first.split(',').map {|i| Integer(i)} }
      if not refine.nil?
        @network[id] = refine.call(bins) 
      else
        @network[id] = bins
      end
      #printf("%d:%s\n", id, @network[id].map { | b | "[#{b.join(',')}]" })
    end
  end
end

class PtrsParser
  def initialize(src)
    load_ptrs(src)
  end

  def get_nodes()
    return @ptrs.keys
  end

  def get_node_ptrs(node_id)
    return @ptrs[node_id]
  end

  private

  def load_ptrs(src)
    @ptrs = {}

    src.each do |line|
      line[/([0-9]+):(-1|[0-9]+),(-1|[0-9]+)/]
      id = Integer($1)
      pred = Integer($2)
      succ = Integer($3)

      @ptrs[id] = [pred, succ]
    end
  end
end

if __FILE__ == $0
  BUCKETSIZE = 5
  parser = LogRandRouteTableParser.new(File.new(ARGV[0]), 
                                       GenRefinement.numeric_limit(BUCKETSIZE))

  nodes = parser.get_nodes
  10.times do | x |
    printf("rand(%d): %d\n", nodes[x], parser.get_node_rt(nodes[x]).random_node)
    printf("rand(%d, 0): %d\n", nodes[x], parser.get_node_rt(nodes[x]).random_node(1))
    printf("rand(%d, 8..16): %d\n", nodes[x], parser.get_node_rt(nodes[x]).random_node(8..16))
    printf("closest(%d, 23): %d\n", nodes[x], parser.get_node_rt(nodes[x]).closest_node(23))
  end
end
