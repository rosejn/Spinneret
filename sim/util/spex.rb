require 'rdoc/usage'
require 'fileutils'
require 'spinneret'
require 'drb'
require 'job_types'

class Exploration
  def self.load(filename)
    e = new
    
    # 2nd filename and line number for error reporting
    e.instance_eval(File.read(filename), filename, 0) 

    e
  end

  def initialize
    @current_experiment = nil
    @params = {}
  end

  def defaults(vals)
    @default_params = vals
  end

  def add_param(name, vals)
    @params[name] = vals
  end

  def to_s
    @default_params.each do |param, vals|
      puts "#{param}: #{vals.inspect}"
    end

    @params.each do |param, vals|
      puts "#{param}: #{vals.inspect}"
    end
  end

=begin
  def method_missing(meth_name, *args)
    add_parameter(meth_name, args)
  end
=end

  def each(name, *list)
    add_param(name, list)
  end

  def static(name, val)
    add_param(name, val)
  end

  def linear(name, start, stop, stride = 1)
    vals = []
    v = start
    while v < stop
      vals << v
      v = v + stride
    end

    add_param(name, vals)
  end

  def log(name, start, stop, n = 2)
    vals = []
    v = start
    while v < stop
      vals << v
      v *= n
    end

    add_param(name, vals)
  end

  def new_experiment(name)
    send_experiment if @current_experiment
    @current_experiment = name
    @params = {}
  end

  def create_job(exec)
    job = RJServe::Jobs::ShellExecute.new()
    job.parse_opt('-jc', exec)
    job
  end

  def make_fresh_dir(path)
    create_job("rm -rf #{path} && mkdir -p #{path}")
  end

  def send_experiment
    @params.each do |param, value|
      jc = RJServe::Jobs::JobChain.new()

      vals = 
    end
  end
end

class Dispatch
  def initialize(server_addr)
    #Connect to the job server object
    DRb.start_service
    job_queue = DRbObject.new(nil, "druby://#{address}")
  end
end

e = Exploration.load(ARGV.shift)
puts "#{e}"
