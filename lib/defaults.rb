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
#    n.maintenance_indegree_walker_smoothing = 0.1 # Needs to be explored / deleted?
    n.maintenance_indegree_walker_local_avg = 40          # Also needs to be explored
    n.maintenance_indegree_walker_ttl = 80          # Also needs to be explored
    n.maintenance_indegree_walker_min_ttl = 20
    n.maintenance_indegree_walker_list_size = 4
    n.maintenance_indegree_walker_rate = 5000   # this value probably needs to be dynamic
    
    # Link Table
    lt = c.link_table = OpenStruct.new
    lt.max_peers = 15   # No longer should be used outside distribution funcs
    lt.address_space = 10000
    lt.distance_func = nil  # set by simulation after final address space 
                            # is known
    lt.size_function = 'homogeneous'
    #lt.trim_algorithm = LTAlgorithms::RandUpper   # must implement trim()
    lt.trim_algorithm = LTAlgorithms::Base
    lt.address_space_divider = 2 # Used only by LTAlgorithms::RandUpper (>= 2)

    # Analyzer
    an = c.analyzer = OpenStruct.new
    an.measurement_period = 10000
    an.output_path = 'output'
    an.graph_tool = true
  end

  set_defaults
end
