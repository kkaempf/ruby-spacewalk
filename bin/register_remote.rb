#
# register_remote
#
# Register a 'remote' client to Spacewalk
#

# for testing: prefer local path
$: << File.expand_path(File.join(File.dirname(__FILE__),"..","lib"))

require "spacewalk"
require File.expand_path(File.join(File.dirname(__FILE__),'client'))

#
# Usage
#

def usage(msg=nil)
  STDERR.puts "*** #{msg}" if msg
  STDERR.puts "Usage:"
  STDERR.puts "  register_remote [<options>] <client-fqdn>"
  STDERR.puts "    --server <spacewalk-server-url>"
  STDERR.puts "    --key <activationkey>"
  STDERR.puts "    --name <visible-name>"
  STDERR.puts "    --description <description>"
  STDERR.puts "    --packages"
  STDERR.puts "    --hardware"
  STDERR.puts "    --solv <solv-file>"
  STDERR.puts "    --arch <arch>"
  STDERR.puts "Does a registration of a 'remote' client system"
  exit(msg ? 1 : 0)
end

#
# parse_args
#  parses command line args and returns Hash
#
def parse_args
  require 'getoptlong'
  opts = GetoptLong.new(
    [ "--help",        "-?",  GetoptLong::NO_ARGUMENT ],
    [ "--server",      "-s",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--name",        "-n",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--description", "-d",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--key",         "-k",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--arch",        "-a",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--packages",    "-p",  GetoptLong::NO_ARGUMENT ],
    [ "--hardware",    "-h",  GetoptLong::NO_ARGUMENT ],
    [ "--solv",        "-S",  GetoptLong::REQUIRED_ARGUMENT ]
  )
  result = {}
  opts.each do |opt,arg|
    result[opt[2..-1].to_sym] = arg
  end
  usage if result[:help]
  usage("No server url given") unless result[:server]
  unless result[:solv]
    usage("No <client-fqdn> given") if ARGV.empty?
    result[:fqdn] = ARGV.shift
    usage("Multiple <client-fqdn>s given") unless ARGV.empty?
  end
  result
end

#------------------------------------
# main()

begin
  parms = parse_args
rescue SystemExit
  raise
rescue StandardError => e
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

  # compute Client information

  client = Client.new fqdn
end

begin
  server = Spacewalk::Server.new :noconfig => true, :server => parms[:server], :systemid => systemid

  puts "  Computing profile"
  # get "os_release","release_name","architecture"
  profile = client.profile
  # override with CLI arg
  profile["architecture"] = parms[:arch] if parms[:arch]
  # if empty, Spacewalk will create it
  profile["description"] = parms[:description]

  unless systemid
    puts "Must register"
    usage("No activationkey given") unless parms[:key]
    puts "Registering"
    systemid = server.register parms[:key], parms[:name]||fqdn, profile
    File.open(fqdn, "w+") do |f|
      f.write systemid
    end
    puts "#{fqdn} successfully registered"
  end

  if parms[:packages]
    packages = client.packages
    server.send_packages packages
  end
  
#  if parms[:hardware]
#    hardware = client.hardware
#    server.refresh_hardware hardware
#  end

rescue
  raise
end
