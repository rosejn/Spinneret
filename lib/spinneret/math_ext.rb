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
end
