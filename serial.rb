require 'rubygems'
require 'serialport'
#require 'readbytes'

class SerialBlocking
  PORT = '/dev/cu.usbserial-A6007CO3'
  BAUD = 9600
  BITS = 8
  STOPBITS = 1
  PARITY = SerialPort::NONE

  def initialize(port = PORT, speed = BAUD, bits = BITS, stopbits = STOPBITS, parity = PARITY)
    open_serial_port(port, speed, bits, stopbits, parity)
  end
  
  def offline?
    @sp == nil
  end
  
  def connect(port = PORT, speed = BAUD, bits = BITS, stopbits = STOPBITS, parity = PARITY)
    puts "failed to connect"
    #open_serial_port(port, speed, bits, stopbits, parity) if offline?
  end
  
  def exchange(send_bytes, response_nbytes )
    write(send_bytes)
    readbytes(response_nbytes)
  end
  
  def readbytes(nbytes = 1)
    if @sp != nil
      begin
        @sp.readbytes(nbytes)
      rescue
        ''
      end
    else
      '' 
    end
  end
  
  def write(bytes)
    if @sp != nil
      begin
        @sp.write(bytes)
      rescue
        ''
      end
    else
      ''
    end
  end
  
  def close
    @sp.close if @sp != nil
    @sp = nil
  end
  
  def self.open(port = PORT, speed = BAUD, bits = BITS, stopbits = STOPBITS, parity = PARITY)
    begin
      open_serial_port(port, speed, bits, stopbits, parity)
        yield @sp
      @sp.close
    rescue => error
      puts error
      @sp = nil
    end
  end
  
  private 
  def open_serial_port(port = PORT, speed = BAUD, bits = BITS, stopbits = STOPBITS, parity = PARITY)
    begin
      @sp = SerialPort.new(port, speed, bits, stopbits, parity)
      @sp.flow_control = SerialPort::NONE
      @sp.read_timeout = 0
    rescue => error
      puts error
      @sp = nil
    end
  end

end