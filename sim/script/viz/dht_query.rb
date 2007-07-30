module Spin
  module Visualization

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
          p1 = [n1.x + n1.width/2, n1.y + n1.height/2]
          @pts << p1
        end

        n2 = @manager.nodes[dest]
        p2 = [n2.x + n2.width/2, n2.y + n2.height/2]
        @pts << p2

        if @pts.length > 1
          @paths << Arc.new(@manager, @pts[-2], @pts[-1], "Gold", 2)
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
          p1 = [n1.x + n1.width/2, n1.y + n1.height/2]
          @pts << p1
        end

        n2 = @manager.nodes[dest]
        p2 = [n2.x + n2.width/2, n2.y + n2.height/2]
        @pts << p2

        if @pts.length > 1
          @paths << Arc.new(@manager, @pts[-2], @pts[-1], "Gold", 2)
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

  end
end
