module Spin
  module Visualization
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

  end
end

