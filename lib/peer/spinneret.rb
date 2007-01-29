# A base implementation of the Spinneret P2P substrate.

# Authors   :: Jeff Rose & Cyrus Hall
# Copyright :: Copyright (c) 2007 the Authors
# License   :: Distributes under the same terms as Ruby

require 'thread'

module Spinneret

  # This class serves as the primary interface to the Spinneret substrate.
  class Member
    DEFAULT_PORT_NUM = 1212

    def initialize(start_ip, start_port = DEFAULT_PORT_NUM)
      @link_table = LinkTable.new
      @table_manager = TableManager.new(@link_table) 

      @maintenance_thread = Thread.new { @table_manager.run(start_ip, start_port) }
    end
    
    # Get a set of random nodes from the link table.  The default is to return a
    # single random node, but more can be requested.
    #
    # [*num*] The number of requested random nodes (not guaranteed)
    def get_random_node(num = 1, allow_duplicates = false)
      @link_table.random_peers(num, allow_duplicates)
    end

    # Get a set of nodes which are closest to the given virtual id.
    #
    # [*id*] The center of the set of close nodes returned
    # [*num*] The number of requested nodes to return (not guaranteed)
    def get_closest_node(id, num = 1)
      @link_table.closest_peers(id, num)
    end

    # Add a peer to the link table.
    #
    # [*peer*] The peer to add
    def add_peer(peer)
      @link_table.store_peer(peer)
    end

    # Remove a peer from the link table.
    #
    # [*id*] The peer to remove
    def remove_peer(id)
      @link_table.remove_peer(peer)
    end

  end

  class TableManager
    def initialize(link_table)
      @link_table = link_table

    end

    def run(start_ip, start_port)
      bootstrap(start_ip, start_port)
      schedule_maintenance
    end
  end

