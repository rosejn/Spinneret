module Spinneret
  class Timeout
    @@timeouts = []
    @@updated = false
    
    class Expiration
      attr_reader :secs, :msecs
      def initialize(msecs)
        @secs = Time.now + msec / 1000
        @msecs = msecs % 1000
      end

      def <=>(exp)
        s = @secs <=> exp.secs
        s = @msecs <=> exp.msecs if s == 0
        s
      end
    end

    # Get the 
    def Timeout.next
      if @@updated
        @@timeouts.sort {|a,b| a.expiration <=> b.expiration }
        @@updated = false
      end

      @@timeouts.first
    end

    # Run any expired timeouts.
    def Timeout.run_timeouts
      while @@timeouts.first and @@timeouts.first.expiration <= Time.now
        t = @@timeouts.shift
        t.handler.call
      end
    end

    # Create a new timeout.
    #
    # [*ms_delay*] Number of milliseconds to wait before calling the timeout handler
    # [*periodic*] Set to true if this should be a periodically recurring timeout
    # [*block*]    The handler to be called when this timeout fires
    def initialize(ms_delay, periodic = false, &block)
      @expiration = Expiration.new(ms_delay)
      @periodic = periodic
      @handler = block

      @@timeouts << self
      @@updated = true
    end

    def cancel
      @@timeouts.delete(self)
    end

  end
end
end
