module Spinneret
  def Spinneret.set_defaults
    c = Configuration::instance

    # Node
    n = c.node = OpenStruct.new
    n.maintenance_algorithm = Maintenance::PushPull  # Must implement 
                                                     # do_maintenance()
    n.maintenance_opportunistic_alwayson = true
    n.maintenance_size = 5
    n.maintenance_rate = 1000

    # Link Table
    lt = c.link_table = OpenStruct.new
    lt.max_peers = 15   # No longer should be used outside distribution funcs
    lt.address_space = 10000
    lt.distance_func = nil  # set by simulation after final address space 
                            # is known
    lt.size_function = 'homogeneous'
    lt.trim_algorithm = LTAlgorithms::Base   # must implement trim()

    # Analyzer
    an = c.analyzer = OpenStruct.new
    an.measurement_period = 10000
    an.output_path = 'output'
    an.graph_tool = true
  end

  set_defaults
end
