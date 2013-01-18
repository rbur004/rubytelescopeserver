=rubytelescopeserver

* Source https://github.com/rbur004/rubytelescopeserver

== DESCRIPTION:

Experiment with Eventmachine driven Stellarium telescope server for a Vixen SX mount.

* Connection to the Vixen mount is through the web interface using the mounts 100TX ethernet port.

Also controls a Moonlite focuser through the serial port.

* Can read position
* set an absolute position
* send a positive or negative change to the current position

A Web interface is also provide to see the current state of the Vixen starbook controller, and make changes to
the position. The starbook does not like being controlled from the web and manually. Hence the web interface.

http://127.0.0.1:8080/

* Displays the starbook screen on the web page
    * Displays an offline .png image of the screen if it can't connect to the starbook
* Reads and displays the Mounts current RA/DEC coordinates
* Displays status of commands being sent to the starbook
* Can tell the Starbook to perform any command one could issue from the Starbook itself
** Has start motor button to get the starbook from power on to its active state.
** Can set Starbook date (as long as the starbook has just started the motors)
** Can specify RA/DEC to go to.
** Manual RA / Dec buttons
** A stop button
** Align button
** Zoom buttons and pop up menu for specific zoom level (Which affects the RA/DEC manual button speed)
* Displays the Moonlite focuser position (as it changes)
* Indicates if the focuser is still moving.
* Can set position
* Preset value
* Preset increments for quicker changes

Telnet interface, for command line control.

 
== FEATURES/PROBLEMS:

Delay from sending instruction to scope moving.
Starbook sometimes locks up, and needs to be restarted to get the web server working again

readbytes has gone in Ruby 1.9.x, so the code needs a rework.
Commented out the require 'readbytes', and it seems to work fine.

I have replaced my Starbook with a Nexstar, having swapped the Vixen mounts controller with a NEXSXD board. 
Time to start this again.


== SYNOPSIS:


== REQUIREMENTS:

* gems eventmachine, eventmachine_httpserver, serialport and chunky_png

== INSTALL:

* sudo gem install 'eventmachine'
* sudo gem eventmachine_httpserver
* sudo gem install chunky_png     #For the display of the Starbook screen on the Web page.
* sudo gem install serialport     #For the Moonlite controller


Manually setting 
*serial port, parity, speed, ... set is serial.rb

*Vixen Starbook port and address set in starbookEMQueue.rb

All set in run_eventmachine.rb
* Listens on port 10001 for commands from Stellarium 
* Runs web server on port 8080
* Listens for telnet commands on port 10012


== LICENSE:

Distributed under the Ruby License.

Copyright (c) 2009

1. You may make and give away verbatim copies of the source form of the
   software without restriction, provided that you duplicate all of the
   original copyright notices and associated disclaimers.

2. You may modify your copy of the software in any way, provided that
   you do at least ONE of the following:

     a) place your modifications in the Public Domain or otherwise
        make them Freely Available, such as by posting said
  modifications to Usenet or an equivalent medium, or by allowing
  the author to include your modifications in the software.

     b) use the modified software only within your corporation or
        organization.

     c) rename any non-standard executables so the names do not conflict
  with standard executables, which must also be provided.

     d) make other distribution arrangements with the author.

3. You may distribute the software in object code or executable
   form, provided that you do at least ONE of the following:

     a) distribute the executables and library files of the software,
  together with instructions (in the manual page or equivalent)
  on where to get the original distribution.

     b) accompany the distribution with the machine-readable source of
  the software.

     c) give non-standard executables non-standard names, with
        instructions on where to get the original software distribution.

     d) make other distribution arrangements with the author.

4. You may modify and include the part of the software into any other
   software (possibly commercial).  But some files in the distribution
   may not have been written by the author, so that they are not under this terms.

5. The scripts and library files supplied as input to or produced as 
   output from the software do not automatically fall under the
   copyright of the software, but belong to whomever generated them, 
   and may be sold commercially, and may be aggregated with this
   software.

6. THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
   IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE.
