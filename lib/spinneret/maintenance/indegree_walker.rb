module Spinneret
  module Maintenance
    module IndegreeMaintenanceWalker

    WalkerMaintenanceInfo = Struct.new(:visit_avg, :last_id, :change_list)

    class IndegreeList
      def initialize
        @list = []
        @size = Configuration::instance::node.maintenance_indegree_walker_list_size
      end

      def <<(id, avg)
        if @list.length > @size
          smallest_idx = 0
          @list.each_with_index do | x, idx | 
            smallest_idx = idx if x[1] < @list[smallest_idx][1]
          end

          if @list[smallest_idx][1] < avg
            @list[smallest_idx][0] = id
            @list[smallest_idx][1] = avg
          end
        else
          @list << [id, avg]
        end
      end
      alias :add :<<
    end # IndegreeList

    def initialize_indegree_walker
      @last_visit = 0
      @visit_avg = WeightedMovingAverage.new(
                          @config.maintenance_indegree_walker_local_avg)
    end
    attr_reader :visit_avg

    def spawn_maintenance_walker
      return if @link_table.size == 0

      peer = @link_table.random_peer  
      avg = BasicAverage.new()
      avg << (@visit_avg.available? ? @visit_avg.avg : 0)
        #ExponentialMovingAverage.new(
        #            (@visit_avg.available? ? @visit_avg.avg : 0), 
        #            @config.maintenance_indegree_walker_smoothing)

      info = WalkerMaintenanceInfo.new(avg, @nid, IndegreeList.new())
      peer.do_indegree_maintenance(info, 
                                   @config.maintenance_indegree_walker_ttl)
    end

    def do_indegree_maintenance(walker_info, ttl)
#      if(@config.maintenance_indegree_walker_ttl - ttl > 
#         @config.maintenance_indegree_walker_min_ttl)
       if ttl == 0

         if @last_visit != 0
           @visit_avg << @sim.time - @last_visit  

# not used for now
=begin
           if @visit_avg.full?
             # should this go above or below the checks for being high-indegree?
             walker_info.visit_avg << @visit_avg.avg  

             # Makes sure that the random walk has sampled enough of the network.
             if(@visit_avg.avg < walker_info.visit_avg.avg)
               walker_info.change_list.add(@nid, @visit_avg.avg)
             end
           end
=end
         end
      end

      if(ttl != 0)
        walker_info.last_id = @nid

        peer = @link_table.random_peer
        peer.do_indegree_maintenance(walker_info, ttl - 1)  unless peer.nil?
      else
        #@@avgs ||= []
        #@@avgs << walker_info.visit_avg.avg
        #@@avgs = @@avgs.shift if @@avgs.length > 50
        #puts "Avg visit gap: #{walker_info.visit_avg.avg} (#{GSL::Vector.alloc(@@avgs).mean})."
        #puts "list of high: #{walker_info.change_list.inspect}"
      end

      @last_visit = @sim.time
    end

    end # IndegreeMaintenanceWalker
  end # Maintenance
end # Spinneret
