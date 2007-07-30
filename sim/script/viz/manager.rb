module Spin
  module Visualization
    class Manager
      include Singleton

      SEARCHES = 0

      attr_reader :map, :spin_conf, :nodes, :use_graphics

      def initialize(use_graphics = false)
        @use_graphics = use_graphics

        @view = GoSim::View.instance

        @view.add_reset_handler { Spin::Simulation.instance.reset }

        @controls = @view.controls
        @log = @view.log

        @map = @view.space_map
        @nodes = {}

        @queries = {}

        # Register to handle various datasets
        GoSim::Data::DataSet.add_handler(:node, &method(:handle_node_update))
        GoSim::Data::DataSet.add_handler(:link, &method(:handle_link_update))
        GoSim::Data::DataSet.add_handler(:dht_search, 
                                         &method(:handle_dht_search_update))
        GoSim::Data::DataSet.add_handler(:converge_measure,
                                         &method(:handle_converge_update))

        #Setup data view
        create_data_pane()
      end

      def show_search(id)
        @queries[id].show
      end

      def hide_search(id)
        @queries[id].hide
      end

      def handle_converge_update(status, value)
        @data_treeview.model.iter_first.set_value(1, value)
      end

      def handle_dht_search_update(status, uid, id, prev_nid, cur_nid)
        sid = "DHT #{id.to_s}"

        case status
        when :new
          @model.append[SEARCHES] = sid
          s = DHTQuery.new(self, id)
          @queries[sid] = s
        end

        @queries[sid].extend_path(prev_nid, cur_nid)
      end

      def repos_nodes
        n = nodes.to_a.sort { | x, y | x[0] <=> y[0] }.map { | x | x[1] }

        n.each_with_index do | node, idx |
          pos =  idx / n.length.to_f 
          rad = (pos * 2 * Math::PI - (Math::PI + Math::PI / 2))
          x = -1.0 * Math::cos(rad) * 250 + 300
          y = -1.0 * Math::sin(rad) * 250 + 300
          node.set_pos(x, y)
        end

        n.each { | node | node.redraw_links() }
      end

      def handle_node_update(status, nid, *args)
        case status
        when :new
          @nodes[nid] = Node.new(self, nid)
          repos_nodes
        when :failure
          @nodes[nid].fail
        end
      end

      def handle_link_update(status, nid1, nid2, *args)
        case status
        when :add
          @nodes[nid1].add_link(nid2)
          @nodes[nid1].out_degree += 1
          @nodes[nid2].in_degree += 1
        when :remove
          @nodes[nid1].remove_link(nid2)
          @nodes[nid1].out_degree -= 1
          @nodes[nid2].in_degree -= 1
        end
      end

      private

      OUT_EDGE_DENSITY = 0
      IN_EDGE_DENSITY  = 1

      def init_ui_vars
        @out_edges = false
        @in_edges = false
        @join_order = false

        @color_mode = OUT_EDGE_DENSITY
      end

      def out_edge_info_handler(widget, event)
        @out_edge_info = !@out_edge_info

        @nodes.each_value { | n | (@out_edge_info ? n.show_out_degree : 
                                                    n.hide_out_degree ) }
      end

      def in_edge_info_handler(widget, event)
        @in_edge_info = !@in_edge_info

        @nodes.each_value { | n | (@in_edge_info ? n.show_in_degree : 
                                                   n.hide_in_degree ) }
      end

      def join_order_info_handler(widget, event)
        @join_info = !@join_info
      end

      def out_edge_density_info_handler(widget, event)
        @color_mode = OUT_EDGE_DENSITY
      end

      def in_edge_density_info_handler(widget, event)
        @color_mode = IN_EDGE_DENSITY
      end

      def create_data_pane
        init_ui_vars()

        global_box = Gtk::VBox.new(false)

        check_box = Gtk::VBox.new(false)
        check_box.border_width = 5

        label = Gtk::Label.new
        label.set_markup("<b>Visual Info</b>")
        label.set_alignment(0,0)
        check_box.add(label)
        check_box.add(Gtk::HSeparator.new())
        button = Gtk::CheckButton.new("_out-edges")
        button.signal_connect("clicked") { |w, e| out_edge_info_handler(w, e) }
        check_box.add(button)
        button = Gtk::CheckButton.new("_in-edges")
        button.signal_connect("clicked") { |w, e| in_edge_info_handler(w, e) }
        check_box.add(button)
        button = Gtk::CheckButton.new("_join order")
        button.signal_connect("clicked") { |w, e| join_order_info_handler(w, e) }
        check_box.add(button)

        global_box.add(check_box)

        check_box = Gtk::VBox.new(false)
        check_box.border_width = 5

        label = Gtk::Label.new
        label.set_markup("<b>Color Info</b>")
        label.set_alignment(0,0)
        check_box.add(label)
        check_box.add(Gtk::HSeparator.new())
        group = button = Gtk::RadioButton.new("out-edge _density")
        button.signal_connect("clicked") { |w, e| out_edge_density_info_handler(w, e) }
        check_box.add(button)
        button = Gtk::RadioButton.new(group, "in-_edge density")
        button.signal_connect("clicked") { |w, e| in_edge_density_info_handler(w, e) }
        check_box.add(button)

        global_box.add(check_box)
        
        @controls.add(global_box)
        @controls.show_all
      end

    end  # Manager
  end  # Visualization
end  # Spin
