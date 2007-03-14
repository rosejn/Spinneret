module Spin
  module Visualization
    class Manager
      include Singleton

      SEARCHES = 0

      attr_reader :map, :spin_conf, :nodes

      def initialize
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

        # Add custom controls
        edge_toggle = Gtk::Button.new("Toggle Nodes")
        edge_toggle.signal_connect("clicked") do
          @nodes.values.each { | n | n.select }
        end

        scrolled_win = Gtk::ScrolledWindow.new
        scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)

        @model = Gtk::ListStore.new(String)
        column = Gtk::TreeViewColumn.new("Searches",
                                         Gtk::CellRendererText.new, {:text => 0})
        @treeview = Gtk::TreeView.new(@model)
        @treeview.append_column(column)
        @treeview.selection.set_mode(Gtk::SELECTION_MULTIPLE)
        scrolled_win.add_with_viewport(@treeview)
        
        @treeview.selection.signal_connect("changed") do | selection |
          selection.selected_each do | model, path, iter |
            show_search(iter.get_value(SEARCHES))
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
          @nodes[nid] = Node.new(self, nid)
          # add node
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

      def handle_dht_update(status, nid, uid, dest, *args)
        case status
        when :new
          @queries[uid] = nid
          @nodes[nid].add_query(uid, dest)
        when :update
          @nodes[@queries[uid]].add_query_point(uid, nid)
        end
      end
    end

    class DHTQuery < Gnome::CanvasGroup
      def initialize(manager, dest)
        @root = manager.map.root
        @manager = manager

        @dest = dest
        @paths = []
        @pts = []

        @shown = false
      end

      def extend_path(src, dest)
        p "src #{src} dest #{dest}"

        if !src.nil?
          n1 = @manager.nodes[src]  
          p1 = [n1.x + Node::SIZE/2, n1.y + Node::SIZE/2]
          @pts << p1
        end

        n2 = @manager.nodes[dest]
        p2 = [n2.x + Node::SIZE/2, n2.y + Node::SIZE/2]
        @pts << p2

        if @pts.length > 1
          @paths << Arc.new(@manager, @pts[-2], @pts[-1], "Gold")
          @paths.last.hide  if !@shown
        end
      end

      def show
        @paths.each { | p | p.show }
        @shown = true
      end

      def hide
        @paths.each { | p | p.hide }
        @shown = false
      end

    end

    module VizComponent
      SCALE = 500
      OFFSET = 10
      
      def tx(p)
        return p * SCALE + OFFSET
      end
      alias :ty :tx

    end

    class Arc < Gnome::CanvasBpath
      def initialize(manager, p1, p2, color, width = 2, arrowhead = false)
        @root = manager.map.root

        @line = nil
        @arrowhead = nil

        path_points = get_arc_points(p1, p2)
        path_def = points_to_bpath(path_points)

        super(@root, {:bpath => path_def,
                      :outline_color => color,
                      :width_pixels => width})

        if arrowhead == true
            @arrowhead = draw_arrow_head(path_points[2], p2, color) 
        end
      end

      def hide
        super
        @arrowhead.hide if @arrowhead == true
      end

      def show
        super
        @arrowhead.show if @arrowhead == true
      end

      private

      def get_arc_points(p1, p2)
        p = [(p2[0] + p1[0]) / 2.0, (p2[1] + p1[1]) / 2.0]
        y_rise = -1.0 * (p2[0] - p1[0]).to_f
        x_run = (p2[1] - p1[1]).to_f
        m_inv = y_rise / x_run

        units = 8.0 #* SimWindow::DISPLAY_SCALE
        angl_inv = Math.atan(m_inv)
        x_purp = p[0] + Math.cos(angl_inv) * units 
        y_purp = p[1] + Math.sin(angl_inv) * units

        m = -1.0 / m_inv
        angl = Math.atan(m)
        x_para_dif = Math.cos(angl) * units
        y_para_dif = Math.sin(angl) * units

        if p1[0] < p2[0];  x = -1.0  else  x = 1.0   end
        mid_arr = [[(x_purp - (x * x_para_dif)), (y_purp - (x * y_para_dif))],
          [(x_purp + (x * x_para_dif)), (y_purp + (x * y_para_dif))]]

        mid_arr.sort! do | x, y |
          point_distance(p1, x) <=> point_distance(p1, y)
        end

        return [[p1[0], p1[1]],
                 mid_arr[0],
                 mid_arr[1],
                [p2[0], p2[1]]]
      end

      def points_to_bpath(point_arr)
        path_def = Gnome::CanvasPathDef.new()
        path_def.moveto(point_arr[0][0], point_arr[0][1]); 
        path_def.curveto(point_arr[1][0], point_arr[1][1], 
                         point_arr[2][0], point_arr[2][1], 
                         point_arr[3][0], point_arr[3][1])
        return path_def
      end

      def get_arrow_head_points(p1, p2)
        arrow_m = (p1[1] - p2[1]) / (p1[0] - p2[0]).to_f
        arrow_ang = Math.atan(arrow_m) #% Math::PI / 2.0

        #$logger.log(DEBUG, "Arrowhead angle is #{arrow_ang}")

        x_arrow = Math.cos(arrow_ang) * 10
        y_arrow = Math.sin(arrow_ang) * 10

#        p p1
#        p p2 
#        p [x_arrow, y_arrow]

        x_arrow *= -1.0  if p1[0] < p2[0]
        y_arrow *= -1.0  if p1[1] > p2[1]

        return [[p2[0] + x_arrow, p2[1] + y_arrow], [p2[0], p2[1]]]
      end

      def draw_arrow_head(p1, p2, color)
        points = get_arrow_head_points(p1, p2)
        return Gnome::CanvasLine.new(@root, {:points => points, 
                                     :fill_color => color,
                                     :width_pixels => 0, 
                                     :last_arrowhead => true,
                                     :arrow_shape_a => 6.0, 
                                     :arrow_shape_b => 6.0,
                                     :arrow_shape_c => 4.0})
      end

      def point_distance(p1, p2)
        return Math.sqrt((p2[0] - p1[0]) ** 2  +  (p2[1] - p1[1]) ** 2)
      end
    end   # Arc

    class Node < Gnome::CanvasGroup
      include VizComponent

      SIZE = 10

      NODE_FILL = 'DeepSkyBlue'
      NODE_SELECTED_FILL = 'Green'
      NODE_OUTLINE = 'black'

      LABEL_FILL = 'white'
      BOX_FILL = 'black'
      BOX_OUTLINE = 'darkgray'

      attr_reader :x, :y, :edges

      @@nodes = {}

      def pos(id)
        pos =  id / 1000.to_f   # Force base lookup in string
        rad = (pos * 2 * Math::PI - (Math::PI + Math::PI / 2))
        @x = -1.0 * Math::cos(rad) * 250 + 300
        @y = -1.0 * Math::sin(rad) * 250 + 300
      end

      def initialize(manager, id)
        @manager = manager
        @id = id
        @map = @manager.map

        @links = {}
        @queries = {}

        @@nodes[id] = self

        @edges = []
        @view = GoSim::View.instance

        pos(id)

        super(@map.root, :x => @x, :y => @y) 
        @circle = Gnome::CanvasEllipse.new(self, 
              :fill_color => NODE_FILL, :outline_color => NODE_OUTLINE, 
              :x1 => 0, :x2 => SIZE,
              :y1 => 0, :y2 => SIZE)

        mid = SIZE / 2
        @label = Gnome::CanvasText.new(self, 
                                       :x => mid, :y => SIZE + 2, 
                                       :fill_color => LABEL_FILL,
                                       :anchor => Gtk::ANCHOR_NORTH,
                                       :size_points => 8,
                                       :text => "#{@id.to_s}")# (#{@neighbor_locs.size})")
#        @label.hide
        @label.text_width
        w = @label.text_width
        @box = Gnome::CanvasRect.new(self, :x1 => mid - (w / 2 + 4), :y1 => SIZE + 2,
                                :x2 => mid + w / 2 + 4,  
                                :y2 => SIZE + @label.text_height + 2,
                                :fill_color => BOX_FILL,
                                :outline_color => BOX_OUTLINE) 
        @box.raise_to_top
        @label.raise_to_top
        @box.hide

        @selected = false

        signal_connect("event") do | item, event |
          if event.event_type == Gdk::Event::BUTTON_PRESS && event.button == 1
            @selected ? deselect : select
          end
        end

        puts "Added Node"
      end

      def add_link(dest_nid)
        puts "dest id #{dest_nid}"
        dest = [@@nodes[dest_nid].x + SIZE/2, @@nodes[dest_nid].y + SIZE/2]
        @links[dest_nid] = Arc.new(@manager, [@x + SIZE/2, @y + SIZE/2], dest, "Red")
        @links[dest_nid].hide if !@selected

        puts "Added Link"
      end

      def remove_link(dest_nid)
        @links.delete(dest_nid).hide
      end
      
      def add_query(uid, q)
        @queries[uid] = DHTQuery.new(@manager, @id, q)
        @queries[uid].hide  if !@selected
      end

      def add_query_point(uid, nid)
        @queries[uid].add_point(nid) 
      end

      def select
        raise_to_top
        @selected = true
        @circle.set(:fill_color => NODE_SELECTED_FILL)
        @label.show
        @box.show
        @links.each_value { | l | l.show }
#        @view.set_data([["foo", "bar", 2]], ["c1", "c2", "c3"])
        @edges.each {|e| e.show }
      end

      def deselect
        @selected = false
        @circle.set(:fill_color => NODE_FILL)
        #@label.hide
        @box.hide
        @links.each_value { | l  | l.hide }
        #@view.clear_data
        @edges.each {|e| e.hide }
      end

=begin
      def refresh
        @label.set(:text => "#{@id.to_s} (#{@neighbor_locs.size})")
        if @selected
          hide_links
          draw_links
        end
      end
=end

    end

  end  # Visualization
end  # Spin

Spin::Visualization::Manager.instance
