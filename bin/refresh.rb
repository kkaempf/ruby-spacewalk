#
# refresh
#

# for testing: prefer local path
$: << File.expand_path(File.join(File.dirname(__FILE__),"..","lib"))

require "spacewalk"
require File.expand_path(File.join(File.dirname(__FILE__),'windows'))

#
# Usage
#

def usage msg
  STDERR.puts "*** #{msg}" if msg
  STDERR.puts "Usage:"
  STDERR.puts "  refresh [--packages] [--hardware] --server <server> <host>"
  exit( msg ? 1 : 0)
end

#
# parse_args
#  parses command line args and returns Hash
#
def parse_args
  require 'getoptlong'
  opts = GetoptLong.new(
    [ "--port",   "-P", GetoptLong::REQUIRED_ARGUMENT ],
    [ "--server",   "-s", GetoptLong::REQUIRED_ARGUMENT ],
    [ "--packages", "-p", GetoptLong::NO_ARGUMENT ],
    [ "--hardware",  "-h", GetoptLong::NO_ARGUMENT ]    
  )
  result = {}
  opts.each do |opt,arg|
    result[opt[2..-1].to_sym] = arg
  end
  usage("No server url given") unless result[:server]
  usage("No <host> given") if ARGV.empty?
  result[:fqdn] = ARGV.shift
  usage("Multiple <host>s given") unless ARGV.empty?
  result
end

#------------------------------------
# main()

parms = parse_args


# Already registered ?

fqdn = parms[:fqdn]

unless File.exist? fqdn
  usage "#{fqdn} is not registered"
end

systemid = File.open(fqdn).read

# retrieve Windows information

windows = Windows.new fqdn, parms[:port]

begin
  server = Spacewalk::Server.new :noconfig => true, :server => parms[:server], :systemid => systemid

  # get basic parameters (ComputerSystem + OperatingSystem)
  windows.profile

  if parms[:packages]
    packages = windows.packages
#    server.send_packages packages
  end
  
  if parms[:hardware]
    hardware = windows.hardware
    server.refresh_hardware hardware
  end
  
rescue
  raise
end
