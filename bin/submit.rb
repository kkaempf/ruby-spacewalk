#
# submit
#
# report action status
#

# for testing: prefer local path
$: << File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'spacewalk'
require File.expand_path(File.join(File.dirname(__FILE__), 'client'))

#
# Usage
#

def usage(msg=nil)
  STDERR.puts "*** #{msg}" if msg
  STDERR.puts 'Usage:'
  STDERR.puts '  submit [<options>] <client-fqdn>'
  STDERR.puts '    --server <spacewalk-server-url>'
  STDERR.puts '    --action <action-id>'
  STDERR.puts '    --message <message>'
  STDERR.puts '    --result <result>'
  STDERR.puts 'Submit action status back to server'
  exit(msg ? 1 : 0)
end

#
# parse_args
#  parses command line args and returns Hash
#
def parse_args
  require 'getoptlong'
  opts = GetoptLong.new(
    ['--help',        '-?',  GetoptLong::NO_ARGUMENT],
    ['--server',      '-s',  GetoptLong::REQUIRED_ARGUMENT],
    ['--action',      '-a',  GetoptLong::REQUIRED_ARGUMENT],
    ['--message',     '-m',  GetoptLong::REQUIRED_ARGUMENT],
    ['--result',      '-r',  GetoptLong::REQUIRED_ARGUMENT]
  )
  result = {}
  opts.each do |opt, arg|
    result[opt[2..-1].to_sym] = arg
  end
  usage if result[:help]
  usage('No server url given') unless result[:server]
  usage('No action id given') unless result[:action]
  unless result[:solv]
    usage('No <client-fqdn> given') if ARGV.empty?
    result[:fqdn] = ARGV.shift
    usage('Multiple <client-fqdn>s given') unless ARGV.empty?
  end
  result
end

# convert actions to promises
# Actions => {"id"=>6434, "version"=>2, "action"=>["packages.remove", [[["accountsservice-devel", "0.6.38", "79.1", "", ""]]]]}
#
def mk_promise(_actions)
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
  server.submit_response parms[:action], '0', parms[:message], { }
rescue
  raise
end
