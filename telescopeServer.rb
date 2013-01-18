require 'rubygems'
require 'eventmachine'
require 'socket'

=begin
-----------------------
server->client:
MessageCurrentPosition (type = 0):

LENGTH (2 bytes,integer): length of the message
TYPE   (2 bytes,integer): 0
TIME   (8 bytes,integer): current time on the server computer in microseconds
           since 1970.01.01 UT. Currently unused.
RA     (4 bytes,unsigned integer): right ascension of the telescope (J2000)
           a value of 0x100000000 = 0x0 means 24h=0h,
           a value of 0x80000000 means 12h
DEC    (4 bytes,signed integer): declination of the telescope (J2000)
           a value of -0x40000000 means -90degrees,
           a value of 0x0 means 0degrees,
           a value of 0x40000000 means 90degrees
STATUS (4 bytes,signed integer): status of the telescope, currently unused.
           status=0 means ok, status<0 means some error


---------------------

client->server:
MessageGoto (type =0)
LENGTH (2 bytes,integer): length of the message
TYPE   (2 bytes,integer): 0
TIME   (8 bytes,integer): current time on the client computer in microseconds
                  since 1970.01.01 UT. Currently unused.
RA     (4 bytes,unsigned integer): right ascension of the telescope (J2000)
           a value of 0x100000000 = 0x0 means 24h=0h,
           a value of 0x80000000 means 12h
DEC    (4 bytes,signed integer): declination of the telescope (J2000)
           a value of -0x40000000 means -90degrees,
           a value of 0x0 means 0degrees,
           a value of 0x40000000 means 90degrees
=end

class TelescopeServer < EventMachine::Connection 
  attr_accessor :running
  attr_accessor :controller
  
  def post_init
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    puts "Telescope Client from #{ip}:#{port}"
    @running = true
    @data = ""
    #send_data "GET /getstatus HTTP/1.0\r\nHost: MagicBob\r\n\r\n" 
  end
    
  def trigger(v)
      if @running
        t = Time.now
        #send_data v.join(' ')
        send_data [ 24,0,t.tv_sec * 1000000 + t.tv_usec, to_iRA(v[0]), to_iDEC(v[1]),0 ].pack('ssQLll')
      end
  end
  
  
  def receive_data(data)
    @data <<  data
    if data != nil
      l = data.unpack('ssQLl') 
      microseconds = l[2] / 1000000.0
      seconds = microseconds.floor
      microseconds = ((microseconds - seconds) * 1000000 ).floor
      ra = from_iRA(l[3])
      dec = from_iDEC(l[4])
      puts ": #{l[0]} #{l[1]} #{Time.at(seconds,microseconds)} #{ra.join(' ')}, #{dec.join(' ')}"
      @controller.gotoradec(ra[0], ra[1], dec[0], dec[1] )
    end
  end
  
  def unbind
    @running = false
  end

  private

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
    (ra * (0x100000000 / 24.0) ).floor & 0xFFFFFFFF
  end
  
  def to_iDEC(dec) #deg, min, sec)
    #(to_decimal(deg,min,sec) * (0x40000000 / 90.0)).floor
    (dec * (0x40000000 / 90.0)).floor & 0xFFFFFFFF
  end
  
  def from_iRA(ra)
    to_deg_min_sec(ra / ( 0x100000000 / 24.0) )
  end
  
  def from_iDEC(ra)
    to_deg_min_sec(ra / (0x40000000 / 90.0) )
  end
    
end
