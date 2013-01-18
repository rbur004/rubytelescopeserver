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

require 'gserver'
require 'socket'

class TelescopeServer < GServer 
    
  def initialize(port = 10001, *args)
    @port = port
    super(port, *args)
  end
  
  def serve(client) 
    begin
      t = Time.now
      puts "#{port} #{t}"
      client.write [ 24,0,t.tv_sec * 1000000 + t.tv_usec, to_RA(15,19,6), to_DEC(-68,32,4),0 ].pack('ssQLll')
      loop do 
        if IO.select([client], nil, nil, 2) != nil
          line = client.read(20)
          if line != nil
            l = line.unpack('ssQLl') 
            line.each_byte { |x| print "#{x} " }
            puts
            microseconds = l[2] / 1000000.0
            seconds = microseconds.floor
            microseconds = ((microseconds - seconds) * 1000000 ).floor
            puts "#{@port}: #{l[0]} #{l[1]} #{Time.at(seconds,microseconds)} #{from_RA(l[3])}, #{from_DEC(l[4])}"
            puts
          end
        else
          sleep 5
          t = Time.now
          client.write [ 24,0,t.tv_sec * 1000000 + t.tv_usec, to_RA(0,24,6 ), to_DEC(-72,4,59.9),0 ].pack('ssQLll')
        end
      end
    rescue Exception => error
      puts error
    end
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
    t = ((decimal - h) * 60 )
    [ sign * h , m = t.floor, (t-m)*60 ]
  end  
  
  def to_RA(deg, min, sec)
    (to_decimal(deg,min,sec) * (0x100000000 / 24.0) ).floor
  end
  
  def to_DEC(deg, min, sec)
      (to_decimal(deg,min,sec) * (0x40000000 / 90.0)).floor
  end
  
  def from_RA(ra)
    to_deg_min_sec(ra / ( 0x100000000 / 24.0) )
  end
  
  def from_DEC(ra)
    to_deg_min_sec(ra / (0x40000000 / 90.0) )
  end
    

end

server = TelescopeServer.new 10003
server.audit = true	# enable logging  
server.start 


server.join
