module Math
  def Math.log2(num)
    Math.log(num) / Math.log(2)
  end
end

class Array
  def bin
    num_bins = Math.sqrt(self.length).ceil
    p num_bins
    bins = Array.new(num_bins, 0)

    min = self.min
    max = self.max + 1
    bin_size = (max - min) / Float(num_bins)
    
    self.each { |v| bins[(v - min) / bin_size] += 1 }

    return [bin_size, min, bins]
  end

  def rand
    return self[Kernel::rand(self.length)]
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
    sum += (o - expected[i])**2 / expected[i]
  end

  return sum
end

def normal_fit(data)
  v = GSL::Vector.alloc(data)
  return [GSL::Stats::mean(v), GSL::Stats::sd(v)]
end
