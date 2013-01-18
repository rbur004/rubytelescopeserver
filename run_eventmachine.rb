#!/usr/bin/ruby
require 'rubygems'
require 'eventmachine'
require_relative 'TelnetServer.rb'
require_relative 'vixenstarbook.rb'
require_relative 'webserver.rb'
require_relative 'telescopeServer.rb'
require_relative 'focus.rb'


EventMachine.run do
  puts "EventMachine"
  starbook = VixenStarBook.new
  focuser = Focus.new
  
  starbook.getplace
  starbook.getstatus
  starbook.setspeed(6)
  starbook.getscreen
  
  #allows telnet commands to move the scope
  EventMachine.start_server("0.0.0.0", 10012, MyTelnetServer) do |con|
    con.controller = starbook
  end
  EventMachine::start_server("0.0.0.0", 8080, WebServer) do |con| #allows web commands to control the scope.
      con.controller = starbook
      con.focuser = focuser
  end

  EventMachine.start_server("0.0.0.0", 10001, TelescopeServer) do |con|
    con.controller = starbook
    EM.add_periodic_timer(2)  do
      con.trigger(starbook.getradec)
    end
  end
  EM.add_periodic_timer(2) do
    starbook.getstatus
  end

  EM.add_periodic_timer(8) do
    starbook.getscreen
    if starbook.location_str == ""
      starbook.getplace
    end
=begin Looks like adding this locks up the system if the focuser is plugged back in    
    if focuser.offline?
      puts "focuser offline: attempting to reconnect"
      focuser.connect
    end
=end
  end

end