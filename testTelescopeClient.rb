#!/usr/bin/ruby
require 'scanf'
require 'rubygems'
require 'eventmachine'
require 'socket'

HOST = "10.0.2.112"
PORT = 10001

class TelescopeClient < EventMachine::Connection 
  attr_accessor :p
  def post_init
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    puts "Telescope Client from #{ip}:#{port}"
    @data = ""
    t = Time.now
    #send_data v.join(' ')
    send_data [ 24,0,t.tv_sec * 1000000 + t.tv_usec, to_iRA(0.9), to_iDEC(5.3),0 ].pack('ssQLll')
  end
    
  def trigger(v)
      puts v.join(' ')
      t = Time.now
      #send_data v.join(' ')
  end
  
  def receive_data(data)
    @data <<  data
    if data != nil
      l = data.unpack('ssQLll') 
      microseconds = l[2] / 1000000.0
      seconds = microseconds.floor
      microseconds = ((microseconds - seconds) * 1000000 ).floor
      ra = from_iRA(l[3])
      dec = from_iDEC(l[4])
      puts "#{@p}: #{l[0]} #{l[1]} #{Time.at(seconds,microseconds)} #{ra.join(' ')}, #{dec.join(' ')} #{l[5]}"
    end
  end
  
  def unbind
  end

  def to_decimal(deg, min, sec)
    if deg < 0
      deg - min / 60.0 - sec / 3600.0
    else
      deg + min / 60.0 + sec / 3600.0
    end
  end
  
  def to_deg_min_sec(decimal)
    if (decimal < 0)
      sign = -1
      decimal = -decimal
    else
      sign = 1
    end
    h = decimal.floor
    #t = ((decimal - h) * 60 )
    #[ sign * h , m = t.floor, (t-m)*60 ] #hours, min, decimal seconds.
    m = (((decimal - h) * 600 ).floor)/10.0
    [ sign * h , m ] #hours , decimal minutes to 1 place
  end  
  
  def to_iRA(ra)#deg, min, sec)
    #(to_decimal(deg,min,sec) * (0x100000000 / 24.0) ).floor
    (ra * (0x100000000 / 24.0) ).floor
  end
  
  def to_iDEC(dec) #deg, min, sec)
    #(to_decimal(deg,min,sec) * (0x40000000 / 90.0)).floor
    (dec * (0x40000000 / 90.0)).floor
  end
  
  def from_iRA(ra)
    to_deg_min_sec(ra / ( 0x100000000 / 24.0) )
  end
  
  def from_iDEC(ra)
    to_deg_min_sec(ra / (0x40000000 / 90.0) )
  end
    
end

class Stop  < EventMachine::Connection 
  def post_init
    EventMachine::stop_event_loop
  end
end

EventMachine.run do
  @server = nil
  EM.connect(HOST, PORT,TelescopeClient) { |con| con.p = 1 }
  EM.connect(HOST, PORT+1,TelescopeClient) { |con| con.p = 2 }
  EM.connect(HOST, PORT+2,TelescopeClient) { |con| con.p = 3 }
end

