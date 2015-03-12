module Spacewalk
  class StatusReport
    def self.status
      status = {}
      # Return a 5-tuple containing information identifying the current operating system.
      # The tuple contains 5 strings: (sysname, nodename, release, version, machine).
      #               (uname -s, uname -n, uname -r, uname -v, uname -m)
      status['uname'] = [`uname -s`.chomp, `uname -n`.chomp, `uname -r`.chomp, `uname -v`.chomp, `uname -m`.chomp]
      begin
	File.open('/proc/uptime') do |f|
	  status['uptime'] = f.read.split(' ').map(&:to_i)
	end
      rescue
	nil
      end
#      puts status.inspect
      status
    end
  end
end
