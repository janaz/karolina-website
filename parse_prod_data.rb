require 'time'
require 'yaml'

hash = File.open('prod-data.txt').each.map{|l| l.split(/\t/)}.inject({}){|h,d| h[d[0]]={title:d[1],desc:d[2],date:Time.parse(d[3].to_s.strip)};h}

puts hash.to_yaml
