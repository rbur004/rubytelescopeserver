require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
require 'cgi'
require 'socket'

class WebServer < EventMachine::Connection
  include EventMachine::HttpServer
  attr_accessor :controller, :focuser
  
  def process_http_request
    resp = EventMachine::DelegatedHttpResponse.new( self )
    parse_query #use CGI lib to parse the arguments.
    
    case @http_request_uri
    when '/empty.html';
      send_empty_page(resp);
      return
    when '/screen.html';
      send_screen_page(resp)
      return
    when '/focuser.html';
      send_focus_page(resp)
      return
    when '/focusform.html';
      send_focus_form(resp)
      return
    when '/screen.png';
      resp.status = 200
      resp.content_type 'image/png'
      resp.content = @controller.screen_png
      resp.send_response
      return
    when '/Goto';
      ra_hour = ra_min = dec_deg = dec_min = 0
      @params.each do |k,v|
        puts "#{k} => #{v}"
        case k
        when 'RA_hour'; ra_hour = v[0]
        when 'RA_min'; ra_min = v[0]
        when 'Dec_deg'; dec_deg = v[0]
        when 'Dec_min'; dec_min = v[0]
        end
      end
      @controller.gotoradec(ra_hour,ra_min,dec_deg,dec_min)
    when '/focuser'; 
      @params.each do |k,v|
        port, ip = Socket.unpack_sockaddr_in(get_peername)
        puts "Web Client from #{ip}:#{port} focuser #{k} => #{v}"
        case k
        when 'Zero';
          @focuser.zero_counter
        when 'position' ;
          if v != nil && v[0] != nil 
            @focuser.position = v[0].to_i 
          end
        when 'up1','up2','up3' ;
          if v != nil && v[0] != nil 
            @focuser.move_out( v[0].to_i ) 
          end
        when 'down1','down2', 'down3' ;
          if v != nil && v[0] != nil 
            @focuser.move_in( v[0].to_i )
          end
        when 'move','Up','Down'; #ignore these
        end
      end
    when '/action'; 
      @params.each do |k,v|
        port, ip = Socket.unpack_sockaddr_in(get_peername)
        puts "Web Client from #{ip}:#{port} starbook #{k} => #{v}"
        case k
        when 'speed';
          new_speed = v != nil && v[0] != nil ? v[0].to_i : @controller.getspeed
          puts "new speed = #{new_speed}"
          if new_speed >= 0 && new_speed <= 8 && new_speed != @controller.getspeed
            @controller.setspeed(new_speed)
          end
        when 'zoom_minus';
          if @controller.getspeed < 8
            @controller.setspeed(@controller.getspeed + 1)
          end
        when 'zoom_plus';
          if @controller.getspeed > 0
            @controller.setspeed(@controller.getspeed - 1)
          end
        when 'ra_plus';  @controller.move(:west)
        when 'ra_minus'; @controller.move(:east)
        when 'dec_plus'; @controller.move(:north)
        when 'dec_minus'; @controller.move(:south)
        when 'stop';  @controller.stop_move
        when 'start'; @controller.start #starts the motors, and will accept move and gotoradec commands.
        when 'settime'; @controller.settime
        when 'home'; @controller.gohome #return to the home position. i.e the power on position.
        when 'quit';
          EM.next_tick do #quit when we are back in the main loop.
            EventMachine::stop_event_loop
          end
        else puts "Unknown #{k} => #{v}"
        end
      end
    when '/','/index.html'
      port, ip = Socket.unpack_sockaddr_in(get_peername)
      puts "Web Client from #{ip}:#{port}"
    end
    send_page(resp)
  end
  
  def send_empty_page(resp)
    resp.status = 200
    resp.content_type 'text/html'
    resp.content = <<-EOF
    <html><head><title></title></head><body></body></html>
EOF
    resp.send_response
  end
  
  def send_focus_page(resp)
    resp.status = 200
    resp.content_type 'text/html'
    resp.content = <<-EOF
    <html><head><title>Focuser</title>
    <META HTTP-EQUIV="Refresh" CONTENT="5;URL=/focuser.html">
    </head>
    <body>
    <H2>Focuser</H2>
    <table cellpadding=5>
    <tr> 
      <td><b>Temperature</b></td>
      <td>#{@focuser.temperature} C</td>
    </tr><tr>
      <td><b>Temp Coefficient</b></td>
      <td>#{@focuser.temperature_coefficient} #{@focuser.temperature_compensation? ? 'on' : 'off'}</td>
    </tr><tr>
     <td><b>Position</b></td>
     <td>#{'%06d' % @focuser.position} #{@focuser.moving? ? 'Moving' : 'Stopped'}</td>
    </tr><tr>
    <td>&nbsp;</td>
     <td>#{'%d'%focuser.step_delay}Steps/second (#{@focuser.full_step? ? 'Full' : 'Half'})</td>
    </tr>
    </table>
    </body></html>
EOF
    resp.send_response
  end

  def send_screen_page(resp)
    resp.status = 200
    resp.content_type 'text/html'
    resp.content = <<-EOF
    <html><head><title>Starbook Screen</title>
    <META HTTP-EQUIV="Refresh" CONTENT="8;URL=/screen.html">
    </head>
    <body>
    <img src="/screen.png"><br>
    <b>#{@controller.location_str}</b><span align=right>#{@controller.queue}</span>
    </body></html>
EOF
    resp.send_response
  end
  
  def send_page(resp)
            resp.status = 200
            resp.content_type 'text/html'
            resp.content = <<-EOF
    <table>
    <tr>
    <td>
      <iframe src ="screen.html" width="320px" height="280px" frameborder="0" scrolling="no" marginwidth="0" marginheight="0"></iframe>

      <table>
      <tr>
        <td>&nbsp;</td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="zoom_plus"><INPUT TYPE=SUBMIT NAME="zoom_plus" Value="Zoom+"></form></td>
        <td>&nbsp;</td>
        <td>&nbsp;</td>
        <td>&nbsp;</td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="dec_plus"><INPUT TYPE=SUBMIT NAME="dec_plus" VALUE="DC+"></form></td>
        <td>&nbsp;</td>
      </tr>
      <tr>
        <td>&nbsp;</td>
        <td>
          <FORM method="post" ACTION="/action" TARGET="empty" NAME="speed">
            <select name="speed" id="speed" onChange="document.speed.submit();" size="1">
              <option value="0" #{@controller.getspeed==0 ? 'selected="yes"' : ''}>0</option>
              <option value="1" #{@controller.getspeed==1 ? 'selected="yes"' : ''}>1</option>
              <option value="2" #{@controller.getspeed==2 ? 'selected="yes"' : ''}>2</option>
              <option value="3" #{@controller.getspeed==3 ? 'selected="yes"' : ''}>3</option>
              <option value="4" #{@controller.getspeed==4 ? 'selected="yes"' : ''}>4</option>
              <option value="5" #{@controller.getspeed==5 ? 'selected="yes"' : ''}>5</option>
              <option value="6" #{@controller.getspeed==6 ? 'selected="yes"' : ''}>6</option>
              <option value="7"#{@controller.getspeed==7 ? 'selected="yes"' : ''}>7</option>
              <option value="8" #{@controller.getspeed==8 ? 'selected="yes"' : ''}>8</option>
            </select>
          </form>
        </td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="align"><INPUT TYPE=SUBMIT NAME="align" VALUE="Align"></form></td>
        <td>&nbsp;</td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="ra_plus"><INPUT TYPE=SUBMIT NAME="ra_plus" Value="RA+"></form></td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="stop"><INPUT TYPE=SUBMIT NAME="stop" Value="Stop"></form></td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="ra_minus"><INPUT TYPE=SUBMIT NAME="ra_minus" VAlue="RA-"></form></td>
      </tr>
      <tr>
        <td>&nbsp;</td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="zoom_minus"><INPUT TYPE=SUBMIT NAME="zoom_minus" VALUE="Zoom-"></form></td>
        <td>&nbsp;</td>
        <td>&nbsp;</td>
        <td>&nbsp;</td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="dec_minus"><INPUT TYPE=SUBMIT NAME="dec_minus" VALUE="DC-"></form></td>
        <td>&nbsp;</td>
      </tr>
      <tr>
        <td>&nbsp;</td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="home"><INPUT TYPE=SUBMIT NAME="home" VALUE="Home"></form></td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="start"><INPUT TYPE=SUBMIT NAME="start" VALUE="Start Motor"></form></td>
        <td><FORM method="post" ACTION="/action" TARGET="empty" NAME="settime"><INPUT TYPE=SUBMIT NAME="settime" VALUE="Set Time"></form></td>
        </td><td colspan=3>
          <FORM method="post" ACTION="/Goto" NAME="Goto" TARGET="empty">
            <table>
            <tr><th>RA</th>
              <td><INPUT TYPE=TEXT  SIZE=5 NAME="RA_hour" VALUE="#{@controller.ra_h}"></td>
              <td><INPUT TYPE=TEXT  SIZE=5 NAME="RA_min" VALUE="#{@controller.ra_min}"></td>
              <td rowspan = 2><INPUT TYPE=SUBMIT NAME="GotoRADec" VALUE="GotoRADec"></td>
            </tr>
            <tr><th>Dec</th>
              <td><INPUT TYPE=TEXT  SIZE=5 NAME="Dec_deg" VALUE="#{@controller.dec_deg}"></td>
              <td><INPUT TYPE=TEXT  SIZE=5 NAME="Dec_min" VALUE="#{@controller.dec_min}"></td>
            </tr></table>
          </form>
          </td><td></td>
      </tr>
      </table>
    </td>
    <td valign=top>
      <iframe src ="focuser.html"  frameborder="0" scrolling="no" marginwidth="0" marginheight="0"></iframe>
      <p>
      <iframe src ="focusform.html"  width="420px" height="240px" frameborder="0" scrolling="no" marginwidth="0" marginheight="0"></iframe>
    </td>
    </tr>
    </table>
    <iframe name="empty" width="1px" height="1px"  src="empty.html"  frameborder="0" scrolling="no" marginwidth="0" marginheight="0"></iframe>
    
    EOF
    resp.send_response
  end
  
  def send_focus_form(resp)
    resp.status = 200
    resp.content_type 'text/html'
    resp.content = <<-EOF
    <html><head><title>Focus Form</title>
    </head>
    <body>
    <table>
    <tr><td>&nbsp;</td><td align="right">
      <FORM method="post" ACTION="/focuser" NAME="Zero" TARGET="empty">
        <INPUT TYPE=SUBMIT NAME="Zero" VALUE="Zero">
      </form>
    </td><td>&nbsp;</td></tr>
    <tr>
    <td> Preset 1 </td>
    <td colspan=2>
      <FORM method="post" ACTION="/focuser" NAME="move" TARGET="empty">
        <INPUT TYPE=TEXT SIZE=6 NAME="position" VALUE="0">
        <INPUT TYPE=SUBMIT NAME="move" VALUE="move">
      </form>
    </td></tr>
    <tr>
    <td> Preset 2 </td>
    <td colspan=2>
      <FORM method="post" ACTION="/focuser" NAME="move" TARGET="empty">
        <INPUT TYPE=TEXT SIZE=6 NAME="position" VALUE="2414">
        <INPUT TYPE=SUBMIT NAME="move" VALUE="move">
      </form>
    </td></tr>
    <tr><td>
      <FORM method="post" ACTION="/focuser" NAME="Up" TARGET="empty">
        <INPUT TYPE=TEXT SIZE=5 NAME="up1" VALUE="5">
        <INPUT TYPE=SUBMIT NAME="Up" VALUE="Up">
      </form>
    </td><td>
      <FORM method="post" ACTION="/focuser" NAME="Up" TARGET="empty">
        <INPUT TYPE=TEXT SIZE=5 NAME="up2" VALUE="10">
        <INPUT TYPE=SUBMIT NAME="Up" VALUE="Up">
      </form>
    </td><td>
      <FORM method="post" ACTION="/focuser" NAME="Up" TARGET="empty">
        <INPUT TYPE=TEXT  SIZE=5 NAME="up3" VALUE="100">
        <INPUT TYPE=SUBMIT NAME="Up" VALUE="Up">
      </form>
    </td></tr>
    <tr><td>
      <FORM method="post" ACTION="/focuser" NAME="Down" TARGET="empty">
        <INPUT TYPE=TEXT  SIZE=5 NAME="down1" VALUE="5">
        <INPUT TYPE=SUBMIT NAME="Down" VALUE="Down">
      </form>
      </td><td>
        <FORM method="post" ACTION="/focuser" NAME="Down" TARGET="empty">
          <INPUT TYPE=TEXT  SIZE=5 NAME="down2" VALUE="10">
          <INPUT TYPE=SUBMIT NAME="Down" VALUE="Down">
        </form>
        </td><td>
        <FORM method="post" ACTION="/focuser" NAME="Down" TARGET="empty">
          <INPUT TYPE=TEXT  SIZE=5 NAME="down3" VALUE="100">
          <INPUT TYPE=SUBMIT NAME="Down" VALUE="Down">
        </form>
    </td></tr>
    </table>
    </body>
    </html>
EOF
    resp.send_response
  end
  def parse_query
    if @http_request_method.upcase == "POST"
      query = @http_post_content == nil ? '' : @http_post_content
    elsif @http_query_string != nil
      query = @http_query_string
    else
      query = ''
    end
    @params = CGI::parse(query)
  end
  
end
