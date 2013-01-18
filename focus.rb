require 'serialQueue.rb'


class Focus
  PORT = '/dev/cu.usbserial-A6007CO3'
  attr_reader :firmware_version
  
  def initialize(serial_port=PORT)
    @serialQueue = SerialQueue.new(serial_port)
    position
    temperature_compensation_off
  end
  
  def offline?
    @serialQueue.offline?
  end
  
  def connect
    @serialQueue.connect if offline?
  end
      
  #set the counter value (don't actually move)
  #defaults to zeroing the counter.
  def set_counter(c = 0)
    @serialQueue.request(":SP#{'%04X' % c}#")
  end
  
  def zero_counter
    @serialQueue.request(':SP0000#') 
  end
  
  #move focuser in c steps
  def move_in(c)
    new_p = @last_position - c
    new_p = 11500 if new_p > 11500
    @serialQueue.request(":SN#{'%04X' % new_p}#:FG#")
  end
  
  #move focuser out c steps
  def move_out(c)
    new_p = @last_position + c
    new_p = 0 if new_p < 0
    @serialQueue.request(":SN#{'%04X' % new_p}#:FG#")
  end
  
  #get the position
  def position
    @serialQueue.request(":GP#",5) do |p|
      return 0 if p.class == NilClass
      return @last_position = p.to_i(16)
    end
  end
  
  #set position and move there. 
  def position=(new_p)
    new_p = 11500 if new_p > 11500
    new_p = 0 if new_p < 0
    @serialQueue.request(":SN#{'%04X' % new_p}#:FG#")
  end
  
  #test if we are moving
  def moving?
    @serialQueue.request(":GI#",3) do |response|
      return response == "00#" ? false : true
    end
  end
  
  #stop and return the position
  def stop
    @serialQueue.request(":FQ#:GP#",5) do |p|
      return p.to_i(16)
    end
  end
  
  #set focuser to half step mode. 
  def half_step
    @serialQueue.request(":SH#")
  end
  
  #test if we are in half step mode
  def half_step?
    @serialQueue.request(":GH#",3) do |m|
      return m == 'FF#'
    end
  end
  
  #set focuser to full step mode
  def full_step
    @serialQueue.request(":SF#")
  end
  
  #test if we are in full step mode.
  def full_step?
    @serialQueue.request(":GH#",3) do |m|
      return m == '00#'
    end
  end
  
  #get the current step delay (movement speed)
  def step_delay
    @serialQueue.request(":GD#",3) do |d|
      case d.to_i(16)
        when 2; return 250 #steps per second
        when 4; return 125 #steps per second
        when 8; return 63 #steps per second
        when 16; return 32 #steps per second
        when 32; return 16 #steps per second.
      end
    end
  end
  
  #set the step delay (movement speed)
  #2 == 250 steps per second
  #4 == 125 steps per second
  #8 == 63 steps per second
  #16 == 32 steps per second
  #32 == 16 steps per second.
  def step_delay=(d)
    @serialQueue.request(":SD#{'%02X' % d}#")
  end
  
  def temperature
    @serialQueue.request(":GT#",5) do |t|
      return t.to_i(16)/2.0
    end
  end
  
  def temperature_compensation_on
    @serialQueue.request(":+#") 
    @temperature_compensation = true
  end
  
  def temperature_compensation_off
    @serialQueue.request(":-#")
    @temperature_compensation = false
  end
  
  def temperature_compensation?
    return @temperature_compensation
  end
  
  def temperature_coefficient
    @serialQueue.request(":GC#", 3) do |t|
      return t.to_i(16)
    end
  end
  
  def temperature_coefficient=(c)
    @serialQueue.request(":SC#{'%02X' % c}#")
  end
  
  def temperature_conversion
    @serialQueue.request(":C#")
  end
  
  def backlight_brightness
    @serialQueue.request(":GB#",3) do |b|
      return b.to_i(16)
    end
  end
  
  def backlight_brightness=(d)
    @serialQueue.request(":SB#{'%02X' % d}#")
  end
  
  def get_firmware_version
    @serialQueue.request(":GV#",3) do |v|
      @version = v.to_i
    end
  end
  
end