#!/usr/bin/ruby
require 'rubygems'
#require 'png'
require 'chunky_png'

class ScreenPNG
  attr_reader :blob
  WIDTH = 320 
  HEIGHT = 240
  
  def initialize(raw_image)
#    canvas = PNG::Canvas.new WIDTH, HEIGHT
    canvas = ChunkyPNG::Image.new WIDTH, HEIGHT

    if raw_image != nil && raw_image.length != 0
      #w,h = 0 , HEIGHT - 1
      w,h = 0 , 0
      l = 115200/3
      v = []
      (0...l).each do |i|
        j = -1
        raw_image[i*3, 3].each_byte do |b|
          v[j+=1] = ((b & 0xF) << 4 )
          v[j+=1] = (b & 0xF0 )
        end
          
        canvas[w,h] = ChunkyPNG::Color.rgb(v[0] , v[1] , v[2])
        w += 1
        if w == WIDTH
          h += 1
          w = 0
        end
=begin #png.rb
        canvas[w,h] = PNG::Color.new(v[0] , v[1] , v[2] )
        w += 1
        if w == WIDTH
          h -= 1
          w = 0
        end
=end

        canvas[w,h] = ChunkyPNG::Color.rgb(v[3] , v[4] , v[5] )
        w += 1
        if w == WIDTH
          h += 1
          w = 0
        end
=begin #png.rb
        canvas[w,h] = PNG::Color.new(v[3] , v[4] , v[5] )
        w += 1
        if w == WIDTH
          h -= 1
          w = 0
        end
=end
      end

      #png = PNG.new canvas
    end
    @blob = canvas.to_blob #png.to_blob
  end
end

  