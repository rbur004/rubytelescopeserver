#!/usr/sbin/ruby
require 'rubygems'
require 'scanf'
require_relative 'screentopng.rb'
require_relative 'starbookEMQueue.rb'

#Vixen's StarBook has an IP port that is used to upgrade the firmware.
#Undocumented, is the use of this port to control the SX mount.
#There are a number of calls I have found so far that all programmatic control
#to go to coordinates, get the current coordinates, and others.

class VixenStarBook
  attr_reader :status_str
  attr_reader :ra_h, :ra_min, :dec_deg, :dec_min, :goto, :state
  attr_reader :time, :time_str
  attr_reader :latitude_dir, :latitude_deg, :latitude_min
  attr_reader :longitude_dir, :longitude_deg, :longitude_min
  attr_reader :location_str
  attr_reader :timezone
  attr_reader :round, :round_str
  attr_reader :version, :version_str
  attr_reader :x, :y, :xy_str
  @@speed = 0
  
  
  def queue
    if block_given?
      yield(@commandQueue.peek)
    else
      @commandQueue.peek
    end
  end
  
  def initialize
    @commandQueue = CommandQueue.new
    @ra_h = @ra_min = @dec_deg = @dec_min = 0
    @status_str = ""
    @location_str = ""
    @time_str = ""
    @default_screen = IO.read("screen.png")
  end
  
  def start
    #returns OK. Can return "ERROR:ILLEGAL STATE".
    #The starbook seems to just look for start in the URL.
    #/restart also works.
    @commandQueue.request( "/start" )
  end
  
  def reset
    #Turns off the mount motor and the StarBook display.
    #Will come out of this state with a /start command, or a power cycle.
    #Nothing is returned.
    @commandQueue.request( "/reset?reset" )
  end
  
  def stop
    #returns OK. Can return "ERROR:ILLEGAL STATE".
    @commandQueue.request( "/stop" )
  end
  
  def getstatus
    #/getstatus
    #returns RA=27+34.7&DEC=000+00&GOTO=0&STATE=SCOPE
    #If the mount is executing a gotoradec. GOTO=1
    #States power on => INIT
    #       Scope mode => SCOPE
    #       Chart mode => CHART
    #       In a menu => USER
    #       Also ALTAZ, but I can't see how to get into this state.
    @commandQueue.request( "/getstatus" ) do |data|
      if data != nil
        d = data.match(/<!--.+-->/).to_s 
        if d != nil
          d.scanf("<!--RA=%d+%f&DEC=%d+%f&GOTO=%d&STATE=%4s-->") do |rah, ram, deg, min, goto, state|
            @ra_h, @ra_min, @dec_deg, @dec_min = rah, ram, deg, min
            @goto, @state = goto, state
            @time = Time.now
            @status_str = "#{@time.strftime('%Y-%m-%d %H:%M:%S')} RA = #{rah} #{ram} DEC=#{deg} #{min} GOTO=#{goto} STATE=#{state}"
          end
          if block_given?
            yield @status_str
          end
        end
      end
    end
  end
  
  def getradec
    return @ra_h + @ra_min/60.0 , @dec_deg + @dec_min/60.0
  end
  
  def gettime
    #returns 2010 3 14 10 31 3 (with + for space in the header version)
    @commandQueue.request("/gettime") do |data|
      if data != nil
        d = data.match(/<!--.+-->/).to_s
        if d != nil
          d.scanf("<!--time=%d+%d+%d+%d+%d+%d-->") do |yy, mm, dd, h, m, s|
            @time =  Time.local yy,mm,dd,h,m,s, 0
            @time_str = "Time = #{@time.strftime('%Y-%m-%d %H:%M:%S')}"
          end
          if block_given?
            yield @time_str
          end
        end
      end
    end
	end

  def getplace
    #returns longitude=E174+28&latitude=S36+58&timezone=12
    @commandQueue.request("/getplace") do |data|
      if data != nil
        d = data.match(/<!--.+-->/).to_s
        if d != nil
          d.scanf("<!--longitude=%c%d+%d&latitude=%c%d+%d&timezone=%d-->") do |long_NS, long_deg, long_min, lat_EW, lat_deg, lat_min, timezone|
            @latitude_dir, @latitude_deg, @latitude_min = long_NS, long_deg, long_min
            @longitude_dir, @longitude_deg, @longitude_min = lat_EW, lat_deg, lat_min
            @timezone = timezone
            @location_str = "#{long_NS}#{long_deg} #{long_min}' #{lat_EW}#{lat_deg} #{lat_min}' TZ #{timezone}"
          end
          if block_given?
            yield @location_str
          end
        end
      end
    end
  end
  
  
	def align(ra = nil, dec = nil)
	  #returns OK
	  if(ra == nil || dec == nil)
      @commandQueue.request("/align")
      #else
    end
    #also can take ra and dec arguments.
	end
	
	def getround
	  #Returns ROUND=8640000-->8640000
	  #This is a full circle on the dec and ra motors in y or x coordinates.
    @commandQueue.request("/getround") do |data|
      if data != nil
        d = data.match(/<!--.+-->/).to_s
        if d != nil
          d.scanf("<!--ROUND=%d-->") do |round|
            @round =  round
            @round_str = "Round = #{round}"
          end
          if block_given?
            yield @round_str
          end
        end
      end
    end
	end
	
	def version
	  #returns version
    @commandQueue.request("/getversion") do |data|
      if data != nil
        d = data.match(/<!--.+-->/).to_s
        if d != nil
          d.scanf("<!--version=%d-->") do |version|
            @version =  version
            @version_str = "Version=#{version}"
          end
          if block_given?
            yield @version_str
          end
        end
      end
    end
	end
	
	def gohome
	  #Scope returns to its power on position.
    @commandQueue.request("/gohome?home=0") 
 	end
    
  #we need a persistent value for the current mount speed setting.
  #This doesn't look to be something the starbook / sphinx mount can tell us.
  def getspeed
    @@speed
  end
  
  def self.speed=(value)
    @@speed = value
  end

  def setspeed(speed = 8)
    #Values from 0(stop) - 8(fast) set the zoom on the screen and 
    #the speed of the mount motors for the move commands 
    @commandQueue.request("/setspeed?speed=#{speed}") 
    VixenStarBook.speed = speed
	end
  
  def move(direction = :stop)
    #Mount moves until a stop_move is sent.
    north,south,east,west = 0,0,0,0
    case direction
    when :north; north = 1
    when :south; south = 1
    when :east; east = 1
    when :west; west = 1
    end
    @commandQueue.request("/move?north=#{north}&south=#{south}&east=#{east}&west=#{west}") 
  end
  
  def stop_move
    move(:stop)
  end
  
	def gotoradec(ra_hour, ra_min, dec_deg, dec_min)
	  #returns OK
	  @commandQueue.request "/gotoradec?RA=#{ra_hour}+#{ra_min}&DEC=#{dec_deg}+#{dec_min}"
  end
  
  def settime(time = nil) #ignoring time parameter for now.
    #Only works in INIT mode.
     t = Time.now
     t -= 3600 if t.dst? #The starbook can't cope with daylight savings in NZ.
    @commandQueue.request "/settime?time=#{t.strftime('%Y+%m+%d+%H+%M+%S')}" 
  end
  
  def setplace(latitude, longitude, timezone)
    #Only works in INIT mode.
    #Need to fix this to chang latitude into %c%03d+%03d and longitude into %c%02d+%02d
    @commandQueue.request "/setplace?longitude=E174+29&latitude=S36+59&timezone=#{timezone}"
  end
  
  def savesettings
    #/savesettings ? Haven't tried it yet
    @commandQueue.request "/savesettings"
  end
  
  def getscreen
    #bitmap of whats on the screen. 320x240 12bit raw image file. To get something that will load
    #in as a colour image, take each 1.5 bytes, left shift the 3 4bit values to use as 8bit RGB values
    #The colour is then close to the screen's actual colour.
    #there are no html headers in the response.
    @commandQueue.request "/screen.bin" do |data|
      if data != nil && data.length != 320 * 240
        @screen_png = ScreenPNG.new(data).blob
      else
        @screen_png = @default_screen
      end
      if block_given?
        yield @screen_png
      end
    end
  end
  
  def screen_png
    @screen_png == nil ? @default_screen : @screen_png
  end  
  
  def getxy
    #returns x and y coordinates of the mount. 0,0 is the power on position
    #getround / 4 is maximum east and west (negative for east) .
    #getround / 2 is maximum south and North  (negative for south) . 
    #i.e.
    #X is the RA axis and ranges from about -2160000 (east) to 2160000 (west).
    #Y is the Dec axis ranges from from about -432000(south) to +432000(north)
    #Useful for telling if the mount should reverse
    #Also useful for swinging the mount to lubricate the worm.
    @commandQueue.request("/getxy") do |data|
      if data != nil
        d = data.match(/<!--.+-->/).to_s
        if d != nil
          d.scanf("<!--X=%d&Y=%d-->") do |x,y|
            @x,@y = x,y
            @xy_str = "X=#{x} Y=#{y}"
          end
          if block_given?
            yield @xy_str
          end
        end
      end
    end
	end
	
=begin
  GET /comet.html
  GET /cometindex.html
  GET /cometfile.html
  POST /postcometfile.html
  GET /send.html?file=filename

comet.html?deldata=abc&number= + document.FormName.number.value + "&i";

<form id="FormName" action="" method="get" name="FormName">
<td><input type="text" name="number" size="24" maxlength="2" value="%d">
<input type="submit" name="idchange" value="No
<td><input type="text" name="sign" size="24" maxlength="10" value="%s"></td>
<td><input type="text" name="name" size="24"
<td><input type="text" name="namej" size="24"  maxlength="28" value="%s"></td>
<td><input type="text" name="periyear" size="6" maxlength="5" value="%d">
<input type="text" name="perimonth" size="2" maxlength="3" value="%d">
<input type="text" name="peridate" size="10" value="%lf">
<td><input type="text" name="periarg" size="24" value="%lf"></td>
<td><input type="text" name="peridist" size="24" value="%lf"></td>
<td><input type="text" name="incl" size="24" value="%lf"></td>
<td><input type="text" name="node" size="24" value="%lf"></td>
<td><input type="text" name="eccen" size="24" value="%lf"></td>
<p><input type="submit" name="update" value="


GET /pecrecord.html
  /pecrec.csv
    Time[s],Count,DeltaRa  
    %d,%d,%f
     downloads the file
  /pecplay.csv
    Time[s],Count,DivRa,RecRa    
    %.1f,%d,%f,%f
  /pecdebug.csv
    Debug parameter
    dialogNest=%d
    %s,%f
    
  /dbgrec.csv
    System Flag Register1: %08x Direc,Sum,Dif,Procs+w  
    %d,%d,%d,%d
  /dbgmonitor.csv 
    bDbgSample,targetRA,cRACount,interval,mv 
    %d,%d,%d,%d,%d
  
GET /monitorpid.csv
  MountParam -1 -1 -1 -1 -1 -1 1
  Time[s],Count,P,I,D,Gain
GET /setmountprm?mountprm1=X&mountprm2=X&mountprm3=X&mountprm4=X&mountprm5=X&mountprm6=X&mountprm7=X

  mountprm 1, through 7

GET /changemac.html
  possible argument ?mac=%2x%2x%2x%2x%2x%2x

GET /updateprogram.html

GET /screen.html
   has a link to /screen.bin

=end

end

