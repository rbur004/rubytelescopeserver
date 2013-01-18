#!/usr/bin/ruby
require 'rubygems'
require_relative 'serial.rb'
require 'serialport'
#require 'readbytes'
require 'eventmachine'


#We need to perform only a single serial port command at a time so 
#this class uses the EventMachine Queue to serialize requests.
class SerialQueue
  
  def initialize(serial_port)
    #create the queue
  	@q = EM::Queue.new
  	@serial_port = serial_port
  	@sp = SerialBlocking.new(serial_port)
  	@pop_proc = lambda do |v|
  	  process_queue(v)
  	end
  	@q.pop @pop_proc  #sets up the first callback to pop_proc  
  end
  
  def offline?
    @sp.offline?
  end
  
  def connect
    @sp.connect(@serial_port) if offline?
  end

  #request a command be sent to the starbook. 
  #Caller is the class that called us
  #message is the command to send.
  def request(message, response_size = 0, &the_block)
    @q.push([message, response_size, the_block])
  end
  
  def process_queue(msg)
    #Process the first message on the queue, sending the command to serial device.
    return if offline?
    data = @sp.exchange(msg[0], msg[1])
	  @q.pop @pop_proc #Set ourselves up to process the next item on the queue.
    if msg[1] > 0 && msg[2] != nil
      msg[2].call(data) #call the block associated with the original request call.
    end
  end
  
  def peek
    if @q != nil
      "Queue #{@q.size}"
    else
      "Queue empty"
    end
  end
  
end


