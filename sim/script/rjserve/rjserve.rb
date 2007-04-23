#!/usr/bin/env ruby

# == Synopsis
#
# rjserve: Run a generic job server
#
# == Usage
#
# -h, --help:
#    Show this help
#
# -n number, --num-procs number
#     Number of processes used to run inserted jobs.  Defualts to 1.
#
# -p number, --port number
#     Specify the local port number to serve jobs on.
#
# = Example:
#
#   ./rjserve -n 3
#   ./rjserve -p 7777 -n 4
#

$:.unshift(File.dirname(__FILE__))
$:.unshift(File.join(File.dirname(__FILE__), 'script', 'rjserve'))

require 'rdoc/usage'
require 'drb'
require 'thread'
require 'job_types'

ENV['PATH'] = ".:" + ENV['PATH']

$num_procs = 1

class RJobServer
  HEAD = :head
  TAIL = :tail

  def initialize
    @queue = []
    @queue_mutex = Mutex.new
    @uid = 0

    start_job_processor
  end

  def add_job(job, position = TAIL)
    @queue_mutex.synchronize do
      case position
      when HEAD
        @queue.insert(0, [job, @uid])
      when TAIL
        @queue << [job, @uid]
      end
      @uid += 1
    end
  end

  def next_job
    job = nil
    @queue_mutex.synchronize do
      job = @queue.shift
    end
    return job
  end

  def get_queue
    return @queue.map { | entry | [entry[0].to_s, entry[1]] }
  end

  def clear_queue
    @queue_mutex.synchronize do
      @queue.clear
    end
  end

  def clear_entries(uid)
    if uid.respond_to? :each
      uid.each { | x | clear_entries(x) }
    end

    @queue_mutex.synchronize do
      entry = @queue.find { | e | e[1] == uid }
      if !entry.nil?
        @queue.delete(entry)
      end
    end
  end

  def start_job_processor
    @processor = Thread.new do 

      @procs = []
      while(1)
        if @procs.length == $num_procs
          @procs.delete(Process.wait)
        end

        job = nil
        while(job.nil? || !job[0].runnable?)
          sleep 0.1
          job = next_job
        end

        puts "Currently spawning job #{job[1]}"
        @procs << fork do
          puts "Running #{job[0]}."
          job[0].run
        end
      end
    end
  end

  def wait_for_jobs
    while(not @queue.empty? or not @procs.empty?)
      sleep(1)
    end
  end
end

port_num = 7005

# If run standalone startup a DRb service.
puts $PROGRAM_NAME 
if $PROGRAM_NAME[/rjserve/]

  opts = GetoptLong.new(['--num-procs', '-n', GetoptLong::REQUIRED_ARGUMENT],
                        ['--port',      '-p', GetoptLong::REQUIRED_ARGUMENT])

  opts.each do | opt, arg |
    case opt
    when '--num-procs'
      $num_procs = arg.to_i    

    when '--port'
      port_num = arg.to_i

    else
      RDoc::usage
      exit(0)
    end
  end

  server_addr = 'localhost' + ':' + port_num.to_s

  printf("RJServe running on %s...", server_addr)
  server = RJobServer.new
  DRb.start_service("druby://#{server_addr}", server)
  printf(" done.  Waiting for jobs.\n")

  DRb.thread.join # Don't exit just yet!
end

