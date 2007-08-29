module Math
  def Math.log2(num)
    Math.log(num) / Math.log(2)
  end
end

module LinkTableDistributions
  # Various table size functions to play with different distributions across
  # the entire network.
  def homogeneous(num)
    return num.round
  end

  def powerlaw(num)
    @@r ||= GSL::Rng.alloc("mt19937")

    k = 2.0
    x_m = (num * k - num) / k.to_f

    return @@r.pareto(k, x_m).round
  end

  def normal(num)
    @@r ||= GSL::Rng.alloc("mt19937")

    sigma = num / 4.0
    x = (num + @@r.gaussian(sigma)).round
  end
end  

class Numeric
  def deltafrom(target, delta)
    return (self - delta) <= target && target <= (self + delta)
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

module MovingAverage
  def avg
    raise "MovingAverage::avg must be redefined."
  end

  def <<(x)
    @pts << x
  end
  alias :add :<<
end

class ExponentialMovingAverage
  include MovingAverage

  attr_reader :adds

  def initialize(guess, alpha)
    @cur_val = guess
    @alpha = alpha
    @adds = 0
  end

  def <<(value)
    @cur_val = @alpha * value + (1.0 - @alpha) * @cur_val
    @adds += 1
  end

  def avg
    return @cur_val
  end
end

class WeightedMovingAverage
  include MovingAverage

  def initialize(size, weight_func = method(:default_weights))
    @pts = []
    @size = size
    @weight_func = weight_func
  end

  def available?
    return !@pts.empty?
  end

  def full?
    return @pts.length >= @size
  end

  def avg
    raise "WeightedMovingAverage::avg: no data points." if @pts.empty?

    size = [@size, @pts.length].min
    weights = @weight_func.call(size)
    @pts = @pts[-size, size]

    sum = 0.0
    @pts.each_with_index { | val, i | sum += weights[i] * val.to_f }

    return sum
  end

  private

  def default_weights(size)
    total_w = (1..size).inject { | sum, x | sum += x }
    return (1..size).to_a.map { | w | w / total_w.to_f }
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

