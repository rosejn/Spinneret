require 'ostruct'

module Spin
  module Visualization

    class VizSettings < OpenStruct
      include Singleton

    end

    def Visualization.set_defaults
      settings = VizSettings::instance

      settings.node = OpenStruct.new
      settings.node.show_indegree = false
      settings.node.show_outdegree = false
      settings.node.show_join_order = false
      settings.node.show_label = true
      settings.node.representation = :vector
      settings.node.move_update = false

      settings.query = OpenStruct.new
      settings.query.query_list = []

      settings.go_sim = OpenStruct.new
      settings.go_sim.view = GoSim::View::instance
      settings.go_sim.controls = settings.go_sim.view.controls
      settings.go_sim.log = settings.go_sim.view.log
      settings.go_sim.root = settings.go_sim.view.space_map.root

      settings.debug = true
    end

    class Manager
      include Singleton

      SEARCHES = 0

      attr_reader :map, :spin_conf, :nodes

      def initialize(use_graphics = false)
        @settings = VizSettings::instance
        Visualization::set_defaults()

        settings.node.representation = :bitmap if use_graphics

        @view = GoSim::View.instance
        @view.add_reset_handler { Spin::Simulation.instance.reset }
        @view.add_render_controler do
          render_all()
          @settings.node.move_update = false
        end

        # !!! Note - this needs to only happen if we are in live mode, else it
        # will fail.  Need to add a way to check if we are live or in trace
        # mode.
        # Turn off graph tool analysis, as it takes a fair amount of time
        Configuration::instance.analyzer.graph_tool = false

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

        # Global simulation state
        @node_join_num = 0
      end

      private

      def show_search(id)
        @queries[id].show
      end

      def hide_search(id)
        @queries[id].hide
      end

      def handle_converge_update(status, value)
        #@data_treeview.model.iter_first.set_value(1, value)
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

      def handle_node_update(status, nid, *args)
        case status
        when :new
          @nodes[nid] = Node.new(self, nid, @node_join_num)
          repos_nodes()
          @node_join_num += 1
        when :failure
          @nodes[nid].fail
        end
      end

      def handle_link_update(status, nid1, nid2, *args)
        case status
        when :add
          @nodes[nid1].add_out_edge(nid2)
          @nodes[nid2].add_in_edge(nid1)
        when :remove
          @nodes[nid1].remove_out_edge(nid2)
          @nodes[nid2].remove_in_edge(nid1)
        end
      end

      OUT_EDGE_DENSITY = 0
      IN_EDGE_DENSITY  = 1

      def repos_nodes
        n = nodes.to_a.sort { | x, y | x[0] <=> y[0] }.map { | x | x[1] }

        n.each_with_index do | node, idx |
          pos =  idx / n.length.to_f 
          rad = (pos * 2 * Math::PI - (Math::PI + Math::PI / 2))
          x = -1.0 * Math::cos(rad) * 250 + 300
          y = -1.0 * Math::sin(rad) * 250 + 300
          node.set_pos(x, y)
        end

        @settings.node.move_update = true
      end

      def render_all
        @nodes.each_value    { |n| n.render() }  unless @nodes.nil?
        @searches.each_value { |s| s.render() }  unless @searches.nil?
      end
      alias :force_render :render_all

      def init_ui_vars
        @out_edges = false
        @in_edges = false
        @join_order = false

        @color_mode = OUT_EDGE_DENSITY
      end

      def out_edge_info_handler(widget, event)
        @settings.node.show_outdegree = !@settings.node.show_outdegree
        @nodes.each_value { |n| n.dirty :out_degree_info }  unless @nodes.nil?
        force_render()
      end

      def in_edge_info_handler(widget, event)
        @settings.node.show_indegree = !@settings.node.show_indegree
        @nodes.each_value { |n| n.dirty :in_degree_info }  unless @nodes.nil?
        force_render()
      end

      def join_order_info_handler(widget, event)
        @settings.node.show_join_order = !@settings.node.show_join_order
        @nodes.each_value { |n| n.dirty :join_order_info }  unless @nodes.nil?
        force_render()
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
