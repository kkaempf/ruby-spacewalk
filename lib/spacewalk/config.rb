module Spacewalk
  class Config
    def initialize path="/etc/sysconfig/rhn/up2date"
      @path = path
      @config = {}
      File.open path do |f|
	while l = f.gets
	  # split <name>=<value>, drop everything else
	  next unless l =~ /(\w+)=(.*)/
	  key = $1
	  val = $2
	  # fixme: handle array-type values
	  @config[key.downcase] = val.empty? ? nil : val
	end
      end
    end
    
    def [] key
      @config[key.downcase]
    end
    
    def method_missing name
      @config[name.to_s.downcase]
    end
  end
end
