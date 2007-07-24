module RJServe
  DEFAULT_PORT = 7005
end

class DRbObject
  def alive?
    begin
      method_missing(:respond_to?, :class, false)
    rescue Exception => e
      return false
    end

    return true
  end
end  

module RJServeHelpers
  attr_reader :servers

  class Resolv
    def initialize(svr_list = "")
      @servers = svr_list.split(",").map { | srv | check_port(srv) }
      path = File.expand_path("~/.rjserve/servers")
      @servers.concat File.read(path).gsub(/\s/, '').split(",").map do | srv |
        check_port(srv)
      end
    end

    def round_robin(num_each = 1, &block)
      raise "Must pass block" if block.nil?
      obj = true

      server_connections = @servers.map do | srv |
        remote_obj = DRbObject.new(nil, "druby://#{srv}")
        alive = remote_obj.alive?
        puts "WARN: removed #{srv} from server list.  Appears dead."
        (alive ? remote_obj : nil)
      end.compact

      while(obj)
        server_connections.each do | cur_srv |
          num_each.times do
            obj = yield
            break if obj.nil?
            cur_srv.add_job(obj)
          end
          break if obj.nil?
        end
      end
    end

    private

    def check_port(srv)
      host, port = srv.split(":")
      port = RJServe::DEFAULT_PORT.to_s if port.nil?
      return host + ":" + port
    end

  end
end
