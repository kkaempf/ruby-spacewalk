#
# fakereg
#

# for testing: prefer local path
$: << File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))

require "spacewalk"

#
# Usage
#

def usage(msg)
  STDERR.puts "*** #{msg}" if msg
  STDERR.puts "Usage:"
  STDERR.puts "  fakereg --server <server> [--port <port>] --key <activationkey> [--description <description>] [--solv <solv> --yaml <yaml>] --arch <arch> --count <count> <name>"
  exit( msg ? 1 : 0)
end

#
# parse_args
#  parses command line args and returns Hash
#
def parse_args
  require 'getoptlong'
  opts = GetoptLong.new(
    ["--server",      "-s",  GetoptLong::REQUIRED_ARGUMENT],
    ["--description", "-d",  GetoptLong::REQUIRED_ARGUMENT],
    ["--key",         "-k",  GetoptLong::REQUIRED_ARGUMENT],
    ["--port",        "-p",  GetoptLong::REQUIRED_ARGUMENT],
    ["--arch",        "-a",  GetoptLong::REQUIRED_ARGUMENT],
    ["--solv",        "-S",  GetoptLong::REQUIRED_ARGUMENT],
    ["--yaml",        "-Y",  GetoptLong::REQUIRED_ARGUMENT],
    ["--count",       "-c",  GetoptLong::REQUIRED_ARGUMENT]
  )
  result = {}
  opts.each do |opt, arg|
    result[opt[2..-1].to_sym] = arg
  end
  usage("No server url given") unless result[:server]
  usage("No activationkey given") unless result[:key]
  usage("No <name> given") if ARGV.empty?
  result[:name] = ARGV.shift
  result
end

#
# Convert Satsolver::Repo to profile list
#
def repo_packages(repo)
  packages = []
  repo.each do |p|
    entry = {}
    entry["name"] = p.name.to_s
    entry["epoch"] = (p.epoch || "0").to_s
    entry["version"] = p.version.to_s
    entry["release"] = p.revision.to_s
    entry["arch"] = p.arch.to_s
    entry["installtime"] = p["solvable:installtime"]
    packages << entry
  end
  packages
end

def fake_profile
  # assemble registration information
  
  data = {}
  data["os_release"] = "Fake testing"
  data["release_name"] = "ruby-spacewalk"
  data["architecture"] = "x86_64"
  data
end
#------------------------------------
# main()

begin
  parms = parse_args
rescue StandardError => e
  usage e.to_s
end

if parms[:solv]
  require 'satsolver'
  pool = Satsolver::Pool.new
  repo = pool.add_solv( parms[:solv] )
  fail "Invalid .solv file: #{parms[:solv]}" unless repo

  if parms[:yaml]
    require 'yaml'
    packages = repo_packages repo
    File.open(parms[:yaml], "w") do |f|
      f.puts "---"
      # somehow, YAML::dump(packages, f) does not work
      packages.each do |p|
        first = true
        p.each do |k, v|
          if first
            f.puts "- #{k}: #{v.inspect}"
            first = false
          else
            f.puts "  #{k}: #{v.inspect}"
          end
        end
      end
    end
    puts "Written #{repo.size} packages to #{parms[:yaml]}"
    exit 0
  end
else
  if parms[:yaml]
    require 'yaml'
    packages = YAML::load_file(parms[:yaml])
  else
    STDERR.puts "No --solv and no --yaml given, skipping packages"
  end
end

count = parms[:count].to_i rescue 1

profile = fake_profile
profile["packages"] = packages

start = Time.now
puts "Start at #{start}, #{count} systems"

threads = []
good = 0
count.times do |i|
  threads[i] = Thread.new do
    begin
      server = Spacewalk::Server.new :noconfig => true, :server => parms[:server]

      # get "os_release","release_name","architecture"
      name = "%s%04d" % [parms[:name], i]
      print "Registering #{name}\n"
      systemid = server.register parms[:key], name, profile
      File.open("#{name}.systemid", "w+") do |f|
        f.write systemid
      end
      print "#{name} successfully registered\n"
      good += 1
    rescue
      STDERR.print "*** #{name} failed: #{e}"
    end
  end
end
puts "Waiting for threads"
threads.each { |t| t.join }

stop = Time.now
elapsed = stop - start
puts "Registered #{good} of #{count} systems in #{elapsed} seconds (#{good / elapsed} systems/sec)"
