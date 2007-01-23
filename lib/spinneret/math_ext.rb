module Math
  def Math.log2(num)
    Math.log(num) / Math.log(2)
  end
end

class Array
  def histogram
    num_bins = Math.sqrt(self.length).ceil
    bins = Array.new(num_bins, 0)

    min = self.min
    max = self.max + 1
    bin_size = (max - min) / Float(num_bins)
    
    self.each { |v| bins[(v - min) / bin_size] += 1 }

    x = []
    start = min + bin_size / 2
    bins.size.times {|i| x[i] = start + i * bin_size }

    return [x, bins]
  end

  def rand
    return self[Kernel::rand(self.length)]
  end

  def randomize
    tmp = []
    copy = self.dup
    self.size.times {|i| tmp << copy.delete(copy.rand)}
    tmp
  end

  def normal_fit
    v = GSL::Vector.alloc(self)
    return [GSL::Stats::mean(v), GSL::Stats::sd(v)]
  end
end

def calc_ideal_binning(num_nodes, addr_space, bin_size)
  density = num_nodes.to_f/addr_space.to_f
  table = Array.new(Math.log2(addr_space).ceil)
  table.each_index do | bin |
    table[bin] = density * (2**(bin+1) - 2**bin)
    table[bin] = bin_size  if table[bin] > bin_size
  end

  return table
end

def chi_squared_distance(observed, expected)
  sum = 0
  observed.each_with_index do |o, i| 
#    printf("(%f - %f)^2 / %f\n", o, expected[i], expected[i])
    if expected[i] == 0
      sum += (o - expected[i])**2 
    else
      sum += (o - expected[i])**2 / expected[i]
    end
  end

  return sum
end

