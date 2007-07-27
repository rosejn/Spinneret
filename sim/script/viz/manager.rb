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
        @data_treeview = @view.data
        data_model = Gtk::ListStore.new(String, Integer)
        convergence = data_model.append
        convergence[0] = "convergence"
        convergence[1] = 0
        text_renderer = Gtk::CellRendererText.new
#        text_renderer.foreground = "Red"
        text_renderer.scale = 2
        @data_treeview.append_column(Gtk::TreeViewColumn.new("Field",
                                                      text_renderer,
                                                      {:text => 0}))
        @data_treeview.append_column(Gtk::TreeViewColumn.new("Value",
                                                      text_renderer,
                                                      {:text => 1}))
        @data_treeview.model = data_model


        # Add custom controls
        edge_toggle = Gtk::ToggleButton.new("Toggle Nodes")
        edge_toggle.signal_connect("clicked") do
          if edge_toggle.active?
            @nodes.values.each { | n | n.select }
          else
            @nodes.values.each { | n | n.deselect }
          end
        end

        scrolled_win = Gtk::ScrolledWindow.new
        scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)

        @model = Gtk::ListStore.new(String)
        column = Gtk::TreeViewColumn.new("Searches",
                                         Gtk::CellRendererText.new, {:text => 0})
        @treeview = Gtk::TreeView.new(@model)
        @treeview.append_column(column)
#        @treeview.selection.set_mode(Gtk::SELECTION_SINGLE)
        scrolled_win.add_with_viewport(@treeview)
        @cur_selected = nil
        
        @treeview.selection.signal_connect("changed") do | selection |
          hide_search(@cur_selected)  if !@cur_selected.nil?
          selection.selected_each do | model, path, iter |
            @cur_selected = iter.get_value(SEARCHES)
            show_search(@cur_selected)
          end
        end

        box = Gtk::VBox.new
        box.pack_start(edge_toggle)
        box.pack_start(scrolled_win, true, true, 0)

        @controls.add(box)
        @controls.show_all
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
        when :remove
          @nodes[nid1].remove_link(nid2)
        end
      end
    end

  end  # Visualization
end  # Spin
