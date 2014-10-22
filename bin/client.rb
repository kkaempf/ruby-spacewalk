#
# Client
# Computes client profile for Spacewalk
#

require 'cgi'

class Client
  #
  # Dump result as XML to file
  #
  def dump klass, result
    File.open("#{klass}.xml", "w+") do |f|
      f.write result.to_xml
    end
  end

  #
  # Constructor
  #
  def initialize host
    @host = host
    @data = {}
  end

  #
  # packages as [ {
  #       "name" => String,
  #       "epoch" => String,
  #       "version" => String,
  #       "release" => String,
  #       "arch" => String,
  #       "installtime" => DateTime }, ... ]
  #
  def packages
    packages = []

    IO.popen("rpm -qa --queryformat \"%{name} %{epoch} %{version} %{release} %{arch} %{installtime}\n\"") do |io|
      io.each do |rpm|
        name,epoch,version,release,arch,installtime = rpm.split(" ")
        next if name == "gpg-pubkey"
        next if arch == "src"
        package = { "name" => name, "epoch" => epoch, "version" => version, "release" => release, "arch" => arch, "installtime" => installtime.to_i }
        puts package.inspect
        packages << package
      end
    end
    
    packages
  end
  
  def profile

    # assemble registration information
    # parse /etc/os-release
    #  NAME=openSUSE
    #  VERSION="13.1 (Bottle)"
    #  VERSION_ID="13.1"
    #  PRETTY_NAME="openSUSE 13.1 (Bottle) (x86_64)"
    #  ID=opensuse
    #  ANSI_COLOR="0;32"
    #  CPE_NAME="cpe:/o:opensuse:opensuse:13.1"
    #  BUG_REPORT_URL="https://bugs.opensuse.org"
    #  HOME_URL="https://opensuse.org/"
    #  ID_LIKE="suse"

    data = { "architecture" => RUBY_PLATFORM.split("-")[0] }
    File.open("/etc/os-release") do |f|
      f.each do |l|
        key, val = l.chomp.split("=")
        val = val[1,-2] if val[0][1] == '"'
        case key
        when "VERSION_ID"
          data["os_release"] = val
        when "PRETTY_NAME"
          data["release_name"] = val
        end
      end
    end
    data
  end


end # client

if $0 == __FILE__
  client = Client.new "1.1.1.1"
  puts client.packages.inspect
end
