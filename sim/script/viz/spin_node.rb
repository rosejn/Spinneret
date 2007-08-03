module Spin
  module Visualization

    class Node < Gnome::CanvasGroup
      REPS = ["img/phone.png", "img/laptop.png"]

      NODE_FILL = 'DeepSkyBlue'
      NODE_SELECTED_FILL = 'Green'
      NODE_OUTLINE = 'black'

      LABEL_FILL = 'white'
      BOX_FILL = 'black'
      BOX_OUTLINE = 'darkgray'

      attr_reader   :x, :y, :edges, :height, :width

      @@nodes = {}

      # Include state-based rendering path
      include StateRenderer

      def initialize(manager, id, join_order)
        @settings = VizSettings::instance

        @manager = manager
        @id = id
        @join_order = join_order

        @@nodes[id] = self

        @in_degree = @out_degree = 0
        @show_out_edges = @show_in_edges = false
        @out_edges, @in_edges = {}, {}

        @queries = {}

        @selected = false
        @failed = false

        pos(id)   # Sets temporary position (likely), as set_pos will be called 
                  # when more nodes join

        super(@settings.go_sim.root, :x => @x, :y => @y) 

        render_init()
        draw_rep()  # draw graphics objects.  after this call, all changes are 
                    # handled via the render() method
        setup_render_path()

        signal_connect("event") do | item, event |
          if event.event_type == Gdk::Event::BUTTON_PRESS 
            # First we set edge state so that the render in select and deselect
            # correct edge displays
            if event.button == 1
              @show_out_edges = !@show_out_edges
            elsif event.button == 3
              @show_in_edges = !@show_in_edges
            else
              @show_out_edges = @show_in_edges = false
            end

            # Push graphics change
            @selected ? deselect : select
          end
        end
      end

      def setup_render_path
        add_render_item :selected,        &method(:node_selected_render)
        add_render_item :failed,          &method(:node_fail_render)
        add_render_item :position,        &method(:position_render)
        add_render_item :out_degree_info, &method(:out_degree_info_render)
        add_render_item :in_degree_info,  &method(:in_degree_info_render)
        add_render_item :join_order_info, &method(:join_order_info_render)
        add_render_item :edges,           &method(:edges_render)
      end

      def select
        @selected = true
        @label.select
        dirty :selected, :edges; render
      end

      def deselect
        @selected = false
        @label.unselect
        dirty :selected, :edges; render
      end

      def fail
        @failed = true
        dirty :failed
      end

      def set_pos(x, y)
        @new_x, @new_y = x, y

        dirty :position, :edges
      end

      def add_out_edge(node)
        add_link(@out_edges, node)
        @out_degree += 1
        dirty :out_degree_info, :edges
      end

      def remove_out_edge(node)
        remove_link(@out_edges, node)
        @out_degree -= 1
        dirty :out_degree_info, :edges
      end

      def add_in_edge(node)
        add_link(@in_edges, node, "Blue")
        @in_degree += 1
        dirty :in_degree_info, :edges
      end

      def remove_in_edge(node)
        remove_link(@in_edges, node)
        @in_degree -= 1
        dirty :in_degree_info, :edges
      end

      private

      def pos(id)
        pos =  id / 1000.to_f
        rad = (pos * 2 * Math::PI - (Math::PI + Math::PI / 2))
        @x = -1.0 * Math::cos(rad) * 250 + 300
        @y = -1.0 * Math::sin(rad) * 250 + 300
      end

      def draw_rep()
        case @settings.node.representation
        when :bitmap
          @@last_rep ||= 0
          im = Gdk::Pixbuf.new(REPS[@@last_rep])
          @@last_rep = (@@last_rep + 1) % REPS.length
          @width = im.width
          @height = im.height
          image = Gnome::CanvasPixbuf.new(self,
                                          :pixbuf => im,
                                          :x => 0,
                                          :y => 0,
                                          :width => im.width,
                                          :height => im.height,
                                          :anchor => Gtk::ANCHOR_NORTH_WEST)
        when :vector
          @size = 10
          @circle = Gnome::CanvasEllipse.new(self, 
                                             :fill_color => NODE_FILL,
                                             :outline_color => NODE_OUTLINE, 
                                             :x1 => 0, :x2 => @size,
                                             :y1 => 0, :y2 => @size)
          @width = @height = @size
        else
          puts "Unknown drawing mode for Spin::Vizualization::Node."
          exit(1)
        end

        @label = TextBox.new(self, "#{@id.to_s}", @width / 2, @height + 2)
        @out_degree_box = TextBox.new(self, "od: #{@out_degree}", 
                                      @width / 2 + 40, @height - 10)
        @in_degree_box = TextBox.new(self, "id: #{@in_degree}", 
                                     @width / 2 + 40, @height + 10)
        @join_order_box = TextBox.new(self, "jo: #{@join_order}", 
                                     @width / 2, @height + 20)

        @label.show
      end

      def add_link(collection, dest_nid, color = "Red")
        dest_node = @@nodes[dest_nid]
        dest = [dest_node.x + dest_node.width/2, dest_node.y + dest_node.height/2]

        link = Arc.new(@manager, [@x + @width/2, @y + @height/2], dest, color, 3)
        link.lower_to_bottom.raise(1).hide

        collection[dest_nid] = link
      end

      def remove_link(collection, dest_nid)
        collection.delete(dest_nid).hide
      end

      def delete_all_links
        [@out_edges, @in_edges].each do | c | 
          c.each_key { | dest | remove_link(c, dest) }
        end
      end

      # Damn this needs to be reimplemented
      def redraw_links()
        @out_edges.each_key do | dest | 
          remove_link(@out_edges, dest); 
          add_link(@out_edges, dest) 
        end

        @in_edges.each_key do | dest |
          remove_link(@in_edges, dest); 
          add_link(@in_edges, dest, "Blue")
        end
      end

      #Render path functions
      def node_selected_render
        if(@selected)
          raise_to_top()
          @label.select

          if(@settings.node.representation == :vector)
            @circle.set(:fill_color => NODE_SELECTED_FILL)
         end
        else
          @label.unselect

          if(@settings.node.representation == :vector)
            @circle.set(:fill_color => NODE_FILL)
          end
        end
      end

      def position_render
        move(@new_x - @x, @new_y - @y)
        @x = @new_x
        @y = @new_y
      end

      def node_fail_render
        Gnome::CanvasLine.new(self, :points => [[0,0], [@width, @height]],
                              :fill_color => "Red",
                              :width_units => 2)
        Gnome::CanvasLine.new(self, :points => [[@width,0], [0, @height]],
                              :fill_color => "Red",
                              :width_units => 2)
        delete_all_links()
      end

      def out_degree_info_render
        if(@settings.node.show_outdegree)
          @out_degree_box.show()
          @out_degree_box.set_value("od: #{@out_degree}")
        else
          @out_degree_box.hide()
        end
      end

      def in_degree_info_render
        if(@settings.node.show_indegree)
          @in_degree_box.show()
          @in_degree_box.set_value("id: #{@in_degree}")
        else
          @in_degree_box.hide()
        end
      end

      def join_order_info_render
        if(@settings.node.show_join_order)
          @join_order_box.show()
          #@join_order_box.set_value("jo: #{@join_order}")
        else
          @join_order_box.hide()
        end
      end

      def edges_render
        #puts "#{@selected} : #{@show_out_edges} : #{@show_in_edges}"
        
        # Have we had end point changes?
        redraw_links()  if @settings.move_update 

        if(@selected)
          if(@show_out_edges)
            @out_edges.each_value { | e | e.show() }
          elsif(@show_in_edges)
            @in_edges.each_value { | e | e.show() }
          end
        else
          [@out_edges, @in_edges].each { | c | c.each_value { |e| e.hide() } }
        end
      end

    end  # Node

  end  #Vis
end  # Spin

