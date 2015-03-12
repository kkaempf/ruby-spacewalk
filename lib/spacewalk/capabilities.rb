module Spacewalk
  class Capabilities
    # 
    def initialize(client)
      # hash of <capability> => <version>
      @caps = {}
      client.http_last_response['x-rhn-server-capability'].split(',').each do |caps|
	caps.split(',').each do |cap|
#	  puts "#{cap}"
	  fail "Invalid cap '#{cap}'" unless cap =~ /(\s+)?(((\w+)|\.)+)\((\d(-\d)?)\)=(\d)/
	  # name = [ version, value ]
	  @caps[Regexp.last_match(2)] = [Regexp.last_match(5), Regexp.last_match(7)]
#	  puts "#{$2}(#{$5})=#{$7}"
	end
      end
    end
  end
end
