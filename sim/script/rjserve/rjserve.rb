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
require 'rjserve_helpers'
require 'socket'

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
    puts "Cleared job queue..."
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

port_num = RJServe::DEFAULT_PORT

# If run standalone startup a DRb service.
puts $PROGRAM_NAME 
if $PROGRAM_NAME[/rjserve/]

  opts = GetoptLong.new(['--num-procs', '-n', GetoptLong::REQUIRED_ARGUMENT],
                        ['--help',      '-h', GetoptLong::NO_ARGUMENT],
                        ['--port',      '-p', GetoptLong::REQUIRED_ARGUMENT])

  opts.each do | opt, arg |
    case opt
    when '--num-procs'
      $num_procs = arg.to_i    

    when '--help'
      RDoc::usage

    when '--port'
      port_num = arg.to_i

    else
      RDoc::usage
      exit(0)
    end
  end

  print "Starting RJServe on port #{port_num}..." 
  server = RJobServer.new
  DRb.start_service("druby://:#{port_num}", server)
  puts " done.  Waiting for jobs.\n"

  DRb.thread.join # Don't exit just yet!
end

