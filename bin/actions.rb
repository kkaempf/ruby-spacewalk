#
# actions
#
# get client actions
#

# for testing: prefer local path
$: << File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))

require "spacewalk"
require File.expand_path(File.join(File.dirname(__FILE__), 'client'))

#
# Usage
#

def usage(msg=nil)
  STDERR.puts "*** #{msg}" if msg
  STDERR.puts "Usage:"
  STDERR.puts "  actions [<options>] <client-fqdn>"
  STDERR.puts "    --server <spacewalk-server-url>"
  STDERR.puts "    --future <hours>"
  STDERR.puts "Checks server for client actions"
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
    [ "--future",      "-f",  GetoptLong::REQUIRED_ARGUMENT ]
  )
  result = {}
  opts.each do |opt, arg|
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

# convert action to promises
#  {"id"=>6434, "version"=>2, "action"=>["packages.remove", [[["accountsservice-devel", "0.6.38", "79.1", "", ""]]]]}
#  {"id"=>6437, "version"=>2, "action"=>["packages.update", [[["aalib-devel", "1.4.0", "503.1.3", "", ""]]]]}
# 
def mk_promise(action)
  id = action["id"]
  task, packages = action["action"]
  promise = "bundle agent "
  case task
  when "packages.remove"
    promise << "mgr_remove"
    policy = "add"
  when "packages.update"
    promise << "mgr_update"
    policy = "remove"
  else
    fail "Task '#{task}' not supported"
  end
  promise << "\n{\n  vars:\n    \"package_list\" slist => {\n      "
  first = true
  packages[0].each do |package|
    name, version, release, epoch, arch = package
    promise << ", " unless first
    first = false
    promise << "\"#{name}-#{version}-#{release}\""
  end
  promise << "\n    }\n  packages:\n    \"$(package_list)\"\n"
  promise << "      package_policy => \"#{policy}\",\n"
  promise << "      package_method => generic,\n"
  promise << "      comment => \"Action #{id}\";\n"
  promise << "}\n"
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

unless File.exist? fqdn
  STDERR.puts "#{fqdn} must be registered first"
end
    
begin
  systemid = File.open(fqdn).read
  server = Spacewalk::Server.new :noconfig => true, :server => parms[:server], :systemid => systemid
  actions = parms[:future] ? server.future_actions(parms[:future].to_i) : server.actions
  if actions
    actions = [ actions ] unless actions.is_a? Array
    actions.each do |action|
      puts mk_promise action
      unless parms[:future]
        server.submit_response parms[:action], "0", "Action converted to promise", { }
      end
    end
  end 
rescue
  raise
end
