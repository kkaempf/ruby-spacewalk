#
# register
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
  STDERR.puts "  register --server <server> --key <activationkey> --name <name> --description <description> <host>"
  exit( msg ? 1 : 0)
end

#
# parse_args
#  parses command line args and returns Hash
#
def parse_args
  require 'getoptlong'
  opts = GetoptLong.new(
    [ "--server",      "-s",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--name",        "-n",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--description", "-d",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--key",         "-k",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--port",        "-p",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--arch",        "-a",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--solv",        "-S",  GetoptLong::REQUIRED_ARGUMENT ]
  )
  result = {}
  opts.each do |opt,arg|
    result[opt[2..-1].to_sym] = arg
  end
  usage("No server url given") unless result[:server]
  usage("No activationkey given") unless result[:key]
  unless result[:solv]
    usage("No <host> given") if ARGV.empty?
    result[:fqdn] = ARGV.shift
    usage("Multiple <host>s given") unless ARGV.empty?
  end
  result
end

#------------------------------------
# main()

begin
  parms = parse_args
rescue Exception => e
  usage e.to_s
end

systemid = nil

# Already registered ?

fqdn = parms[:fqdn]

if fqdn
  if File.exist? fqdn
    STDERR.puts "#{fqdn} is already registered"
    systemid = File.open(fqdn).read
  end

  # retrieve Windows information

  windows = Windows.new fqdn, parms[:port]
end

begin
  server = Spacewalk::Server.new :noconfig => true, :server => parms[:server], :systemid => systemid

  unless systemid
    puts "Must register"
    puts "Retrieving Windows profile"
    # get "os_release","release_name","architecture"
    profile = windows.profile
    # override with CLI arg
    profile["architecture"] = parms[:arch] if parms[:arch]
    # if empty, Spacewalk will create it
    profile["description"] = parms[:description]
    puts "Registering"
    systemid = server.register parms[:key], parms[:name]||fqdn, profile
    File.open(fqdn, "w+") do |f|
      f.write systemid
    end
    puts "#{fqdn} successfully registered"
  end

rescue
  raise
end
