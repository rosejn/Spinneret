require 'singleton'

require 'fcntl'
require 'socket'

module Spinneret
  module Base
    def initialize
      @reactor = Reactor.instance
    end
  end

  class Timeout
    include Base

    def initialize(time, is_periodic, block)
      super()

      @time = time
      @is_periodic = is_periodic
      @block = block
      @active = true

      setup_timer
    end

    def setup_timer
      @active = true
      @reactor.schedule_event(:timeout, @sid, @time, self)
      #log "Timeout started for #{@sid} in #{@time} units"
    end
    alias start reset

    def cancel
      @active = false
      #log "Timeout stopped for #{@sid}"
    end
    alias stop cancel

    def start
      @active = true
      setup_timer
    end

    def handle_timeout(timeout)
      #log "sid -> #{@sid} running timeout"
      # Test twice in case the timeout was canceled in the block.
      @block.call(self) if @active
      setup_timer if @active and @is_periodic
    end

    def inspect
      sprintf("#<GoSim::SimTimeout: @time=%d, @is_periodic=%s, @active=%s>",
            @time, @is_periodic, @active)
    end
  end
    end
  end

  class Reactor
    include Singleton

    DEFAULT_HOSTNAME = 'localhost'
    DEFAULT_PORT     = 8442

    def initialize
      @running = false

      @send_sock = UDPSocket.new
      @server_sock = nil
      @server_handler = nil
      @send_q = []
    end

    def listen(hostname = DEFAULT_HOSTNAME, 
               port     = DEFAULT_PORT,
               &msg_handler)
      @server_sock = UDPSocket.open
      @server_sock.bind(hostname, port)
      @server_handler = msg_handler
    end

    def send_packet(receivers, pkt)
      @send_q << [[receivers].flatten, pkt]
    end

    def stop
      @running = false
    end

    def running?
      @running
    end

    def run
      @running = true

      while @running
        next_timeout = Timer.next
        do_select(next_timeout)
      end
    end

    def do_select(timeout)
      w = @send_q.empty? ? nil : @send_sock
      reader, writer, error = select(@server_sock, w, nil, timeout)

      do_read if reader
      do_write if writer
    end

    def do_read

    end

    def do_write

    end
  end
end
