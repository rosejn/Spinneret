#! /usr/bin/env ruby

# == Synopsis
#
# gen-substrate-wl: Generates a workload for spinneret tests
#
# == Usage
#
# gen-substrate-wl.rb [OPTIONS] FILENAME
#
# -h, --help:
#    Show this help
#
# -o filename, --filename filename
#    Sets the output file
#
# -l num, --sim-max-length num
#    Sets the maximum length of the generated workload
#
# -a num, --address-space num:
#    The address space of the workload
#
# -n num, --num-nodes num:
#    Number of nodes in network
#
# -f, --all-joins-first:
#    All nodes join the network first
#
# -j secs, --mean-join-time secs:
#    Time between nodes joining the network, where 0 is instantanious.  0 is
#    the default.
#
# -x secs, --mean-failure-time secs:
#    Time between failure for each node, where 0 is no failure.  0 is the 
#    default.
#
# -q secs, --mean-leave-time secs:
#    Mean time before a node leaves the network, where 0 is never.  0 is the 
#    default.
#
# -r secs, --mean-rejoin-time secs:
#    Mean time before a node rejoins the network after leaveing or a failure,
#    where 0 indicates nodes to not rejoin.  0 is the default.
#
# -s secs, --mean-search-time secs:
#    Time between searching for each node, where 0 is no search.  0 is the 
#    default. 
#
# FILENAME: The file into which the workload is dumped

######
# The basic FSM for this generator is as follows:
#
#   join    ---------   leave    ------ 
# -------->| running |--------->| left |
#       --> ---------            ------ 
#      /    /    ^  \                ^
#     /    /      \  \failure        |
#     |    |      |   \    --------  | leave
#     |     \    /     \->| failed |-/
#     |      ----          -------- 
#     |     search             |
#     |                       /
#     \----------------------/
#             recover
#
######

# Builtins
require 'singleton'
require 'getoptlong'
require 'rdoc/usage'

# Externals
require 'gsl'
require 'gosim'

class WLPrinter
  include Singleton

  def init(sim, file)
    @sim = sim
    @last_time = -1
    @file = file
  end

  def printf(fmt_str, *args)
    if(@sim.time > @last_time)
      @last_time = @sim.time
      @file.write("time #{@sim.time}\n")
    end

    @file.write(sprintf(fmt_str, *args))
  end

  def flush()
    @file.close()
  end
end

class Killer < GoSim::Entity
  def initialize(end_time)
    super()

    @sim.schedule_event(:die, @sid, end_time, nil)
  end

  def handle_die(e)
    WLPrinter.instance.flush()
    exit(0)
  end
end

opts = GetoptLong.new(
        ['--help',               '-h', GetoptLong::NO_ARGUMENT],
        ['--filename',           '-o', GetoptLong::REQUIRED_ARGUMENT],
        ['--sim-max-length',     '-l', GetoptLong::REQUIRED_ARGUMENT],
        ['--address-space',      '-a', GetoptLong::REQUIRED_ARGUMENT],
        ['--num-nodes',          '-n', GetoptLong::REQUIRED_ARGUMENT],
        ['--all-joins-first',    '-f', GetoptLong::NO_ARGUMENT],
        ['--mean-join-time',     '-j', GetoptLong::REQUIRED_ARGUMENT],
        ['--mean-failure-time',  '-x', GetoptLong::REQUIRED_ARGUMENT],
        ['--mean-leave-time',    '-q', GetoptLong::REQUIRED_ARGUMENT],
        ['--mean-rejoin-time',   '-r', GetoptLong::REQUIRED_ARGUMENT],
        ['--mean-search-time',   '-s', GetoptLong::REQUIRED_ARGUMENT] )

Settings = Struct.new("Settings", :addr_space, :join_first, 
                                  :mjt, :mft, :mlt, :mrt, :mst)
class Settings
  def to_s
   "# Settings:\n# Addr space: #{addr_space}\n# Join first?: #{join_first}\n" +
   "# mjt: #{mjt}\n# mft: #{mft}\n# mft: #{mlt}\n# mrt: #{mrt}\n# mst: #{mst}\n"
  end
end

settings = Settings.new(0, false, 0, 0, 0, 0, 0)

nodes = 0
filename = nil
length = 0
opts.each do | opt, arg |
  case opt
  when '--help'
    RDoc::usage
  when '--filename'
    filename = arg
  when '--sim-max-length'
    length = arg.to_i
  when '--address-space'
    settings.addr_space = arg.to_i
  when '--num-nodes'
    nodes = arg.to_i
  when '--all-joins-first'
    settings.join_first = true
  when '--mean-join-time'
    settings.mjt = arg.to_f
  when '--mean-failure-time'
    settings.mft = arg.to_f
  when '--mean-leave-time'
    settings.mlt = arg.to_f
  when '--mean-rejoin-time'
    settings.mrt = arg.to_f
  when '--mean-search-time'
    settings.mst = arg.to_f
  end
end

if(settings.addr_space == 0 || settings.mjt == 0 || filename.nil?)
  printf("Need to specify at least --address-space, --mean-join-time, " +
         "and --filename.\n")
  exit(0)
end

if(settings.join_first && nodes == 0)
  printf("Must specify --num-nodes when using the --all-joins-first option.\n")
  exit(0)
end

if(length == 0)
  printf("WARN: generating an inifinte trace.\n")
else
  Killer.new(length)
end

file = File.open(filename, "w")
file.write(settings)
file.write("# num nodes: #{nodes}\n")
file.write("# length of simulation: #{length}\n")

puts settings

WLPrinter.instance.init(GoSim::Simulation.instance, file)

GSL::Rng.env_setup
$R = GSL::Rng.alloc("mt19937")

class NodeList
  include Singleton

  attr_accessor :nodes
end

class NodeFactory < GoSim::Entity
  def initialize(num_nodes, settings)
    super()

    @num_nodes, @settings = num_nodes, settings
    @num_nodes = -1  if @num_nodes == 0   # Generating an inifinite number

    NodeList.instance.nodes = []
    @wl = WLPrinter.instance

    @sim.schedule_event(:node_gen, @sid, 
                        $R.poisson(@settings.mjt).round, nil)
  end

  def handle_node_gen(e)
    nodes = NodeList.instance.nodes

    if nodes.length == @settings.addr_space
      printf("ERROR: Address space full.\n")
      exit(1)
    end

    while(nodes.include?(node_id = rand(@settings.addr_space)))  
    end
    @wl.printf("%d init %d\n", node_id, node_id)
    NodeObj.new(node_id, @settings)  if !@settings.join_first
    nodes << node_id

    @num_nodes -= 1
    if(@num_nodes != 0)
      @sim.schedule_event(:node_gen, @sid, 
                          $R.poisson(@settings.mjt).round, nil)
    elsif(@settings.join_first)
      spawn_nodes
    end
  end

  private

  def spawn_nodes
    NodeList.instance.nodes.each { | n | NodeObj.new(n, @settings) }
  end
end

class NodeObj < GoSim::Entity
  def initialize(id, settings)
    super()

    @id, @settings = id, settings
    @left = false
    
    @wl = WLPrinter.instance

    if @settings.mft != 0 
      @sim.schedule_event(:failure, @sid, 
                          $R.poisson(@settings.mft).round, nil)  
    end

    if @settings.mlt != 0
      @sim.schedule_event(:leave, @sid, 
                          $R.poisson(@settings.mlt).round, nil)  
    end

    if @settings.mst != 0    
      @sim.schedule_event(:send, @sid, 
                          $R.poisson(@settings.mst).round, nil)     
    end
  end

  def handle_send(e)
    if(!@left)
      @wl.printf("%d search %d\n", @id, rand(@settings.addr_space))
    end
    @sim.schedule_event(:send, @sid, 
                        $R.poisson(@settings.mst).round, nil)
  end

  def handle_failure(e)
    return  if @left == true

    @wl.printf("%d failure\n", @id)
    @left = true
    if @settings.mrt != 0
      @sim.schedule_event(:recover, @sid, 
                          $R.poisson(@settings.mrt).round, nil)
    end
  end

  def handle_leave(e)
    @wl.printf("%d leave\n", @id)
    @left = true
    NodeList.instance.nodes.delete(@id)
  end
  
  def handle_recover(e)
    @wl.printf("%d recover\n", @id)
    @left = false
    @sim.schedule_event(:failure, @sid, 
                        $R.poisson(@settings.mft).round, nil)
  end
end

NodeFactory.new(nodes, settings)
GoSim::Simulation.run()
