require 'rubygems'
require 'eventmachine'
require 'scanf'
require 'socket'

class MyTelnetServer < EventMachine::Connection 
  attr_accessor :controller
  
  def post_init
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    puts "Telnet Client from #{ip}:#{port}"
  end
     
  def receive_data(data)
    case data[0,1]
    when "2"; @controller.move(:south)
    when "4"; @controller.move(:east)
    when "5"; @controller.stop_move
    when "6"; @controller.move(:west)
    when "8"; @controller.move(:north)
    when '0'; @controller.gohome 
    when "a"; @controller.align 
    when "s"; 
        case data
        when /start/; @controller.start 
        when /status/; @controller.getstatus { |data| send_data data }
        when /s[0-9]/; @controller.setspeed(data[1,1].to_i)
        end
    when 'q'; @controller.queue { |data| send_data data }
    when "r"; @controller.start
    when "R"; @controller.reset
    when "m"; 
      @controller.getscreen  do |screen_png|
        send_data screen_png
      end
    when "e"; EventMachine::stop_event_loop
    when 'x'; @controller.getxy { |data| send_data data }
    when 't';
      @controller.gettime do |data|
        send_data data
      end
    end
  end
  
  def unbind
  end
end
