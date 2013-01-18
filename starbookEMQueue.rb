#!/usr/bin/ruby
require 'rubygems'
require 'eventmachine'

HOST = "10.2.4.144" #"169.254.1.1"
PORT = 80

#Send the command to the StarBook.
#We can only ever have one of these at a time as the starbook wont
#accept more than one connection. Hence we need a command 
#queue to feed this class.
#
#Note that the starbook sends back badly formed HTML. There is no body tag.
#The response is in a comment between the <html> and <head> tags.
#It is also a string between the </head> and </html> tags.
class StarBookCommand < EventMachine::Connection
  include EM::Deferrable

  def post_init
    set_comm_inactivity_timeout(60)
  end
  
  #send the command
  def send(command)
    @data = ""
    set_comm_inactivity_timeout(15)
    send_data "GET #{command} HTTP/1.0\r\nHost: TelescopeServer\r\n\r\n"
    if command == '/reset?reset' #a reset never returns a packet and doesn't close the connection.
      close_connection_after_writing #doesn't always work and starbook need power cycle
    end
  end

  #collect the response
  def receive_data(data) 
    @data <<  data
  end 

  #trigger the callback.
  def unbind
    set_deferred_status :succeeded, @data
  end
end

#We need to perform only a single starbook command at a time so 
#this class uses the EventMachine Queue to serialize requests.
class CommandQueue
  
  def initialize
    #create the queue
  	@q = EM::Queue.new
  	@pop_proc = lambda do |v|
  	  process_queue(v)
  	end
  	@q.pop @pop_proc  #sets up the first callback to pop_proc  
  end
  
  #request a command be sent to the starbook. 
  #Caller is the class that called us
  #message is the command to send.
  def request(message,&the_block)
    @q.push([message, the_block])
  end
  
  def process_queue(msg)
    #Process the first message on the queue, sending the command to StarBookCommand.
    begin
      #puts "Connecting to starbook"
      @starbook = EM.connect(HOST, PORT, StarBookCommand) do |con|
        con.send(msg[0])
      end
    rescue Exception => error
      puts "#{error}: #{msg[0]}" 
  	  @q.pop @pop_proc #Set ourselves up to process the next item on the queue.
      if msg[1] != nil
        msg[1].call(nil)
      end
      return
    end
  
    #Register the callback function for the StarBookCommand.
    #The call back's block runs when StarBookCommand.unbind calls set_deferred_status.
    #This could happen sometime in the future, after process_queue has returned.
    @starbook.callback do |data|
  	  @q.pop @pop_proc #Set ourselves up to process the next item on the queue.
      if msg[1] != nil
        msg[1].call(data) #call the block associated with the original request call.
      end
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


