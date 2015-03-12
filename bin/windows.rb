#
# Windows
# Interfaces to Windows system via WINRM protocol
#

require 'openwsman'
require 'cgi'

class Windows
  # mapping for Registry 'root' pointers
  HKEYS = {
    :HKEY_CLASSES_ROOT   => 2147483648, # (0x80000000)
    :HKEY_CURRENT_USER   => 2147483649, # (0x80000001)
    :HKEY_LOCAL_MACHINE  => 2147483650, # (0x80000002)
    :HKEY_USERS          => 2147483651, # (0x80000003)
    :HKEY_CURRENT_CONFIG => 2147483653, # (0x80000005)
    :HKEY_DYN_DATA       => 2147483654 # (0x80000006)
  }
  TYPES = {
    1 => :REG_SZ,           # string
    2 => :REG_EXPAND_SZ,    # expanded string
    3 => :REG_BINARY,       # blob
    4 => :REG_DWORD,        # integer
    7 => :REG_MULTI_SZ,     # multi string
  }

  def dump(klass, result)
    File.open("#{klass}.xml", "w+") do |f|
      f.write result.to_xml
    end
  end

  def initialize(host, port = 5985)
    @data = {}
    port ||= 5985 # if an explicit nil is passed
    @wsurl = "http://wsman:secret@#{host}:#{port}/wsman"
    @wsman = Openwsman::Client.new @wsurl
    @wsman.transport.timeout = 5
    @wsman.transport.auth_method = Openwsman::BASIC_AUTH_STR
    @wsopt = Openwsman::ClientOptions.new
#    @wsopt.set_dump_request
#    Openwsman.debug = -1
    
    @wsopt.flags = Openwsman::FLAG_ENUMERATION_OPTIMIZATION
    @wsopt.max_elements = 999
  end

  def fault(result = nil)
    if result && result.fault?
      fault = Openwsman::Fault.new result
      STDERR.puts "Fault code #{fault.code}, subcode #{fault.subcode}"
      STDERR.puts "\treason #{fault.reason}"
      STDERR.puts "\tdetail #{fault.detail}"
    else
      STDERR.puts "Generic fault"
      STDERR.puts "Client error #{@wsman.last_error}"
      STDERR.puts "Client msg   #{@wsman.fault_string}"
    end
  end

  def packages
    puts "Enumerating package information"
    # Class uri
    # note the root/default namespace (not root/cimv2)
    #
    uri = "http://schemas.microsoft.com/wbem/wsman/1/wmi/root/default/StdRegProv"

    # Selectors are for key/value pairs identifying instances
    #
    # StdRegProv is a Singleton, no selectors needed
    #
    # options.add_selector( "key", value )
    
    # Properties add method parameters
    # (Marked with [in] in method definitions)
    #
    # The hDefKey is optional and defaults to 2147483650 (HKEY_LOCAL_MACHINE)
    # The sSubKeyName is the path name within the Registry
    #

    uninstall_key = "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
    properties = {
      "hDefKey" => HKEYS[:HKEY_LOCAL_MACHINE].to_s,
      "sSubKeyName" => uninstall_key
    }
    @wsopt.properties = properties
    @wsopt.set_dump_request    
    # Name of method invoked on the class (resp. instrance)
    method = "EnumKey"
    result = @wsman.invoke(@wsopt, uri, method)
#    dump method, result
    if result.nil? || result.fault?
      fault
      return []
    end
    puts result.to_xml
    # map Registry keys to package keys
    keymap = {
      "DisplayName" => "name",
      "DisplayVersion" => "version",
      "InstallDate" => "installtime"
    }
    packages = []

    result.EnumKey_OUTPUT.each("sNames") do |node|
      puts "Node #{node.text.inspect}"
      properties["sSubKeyName"] = uninstall_key + "\\" + CGI::escapeHTML(node.text)
      puts "sSubKeyName >#{properties['sSubKeyName']}<"
      @wsopt.properties = properties
      method = "EnumValues"
      subresult = @wsman.invoke(@wsopt, uri, method)
      if subresult.nil? || subresult.fault?
        fault
        break
      end
      puts subresult.to_xml
      next unless subresult.Types
      # expect sNames. Types arrays
      types = []
      subresult.Types.each do |key|
        types << key.text.to_i
      end
    
      package = {
        "name" => node.text,
        "epoch" => "",
        "version" => "",
        "release" => "",
        "arch" => "i386"
      }
      subresult.sNames.each do |key|
        packagekey = keymap[key.text]
        next unless packagekey
        type = types.shift
        fail "sName #{key} has no type" unless type
        reg_type = TYPES[type]
        method, valuename = case reg_type
          when :REG_SZ
            ["GetStringValue", "sValue"]          # string
          when :REG_EXPAND_SZ
            ["GetExpandedStringValue", "sValue"]  # expanded string
          when :REG_BINARY
            ["GetBinaryValue", "uValue"]          # blob
          when :REG_DWORD
            ["GetDWORDValue", "uValue"]           # integer
          when :REG_MULTI_SZ
            ["GetMultiStringValue", "sValue"]     # multi string
          else
            fail "Unknown type #{type}"
          end
        subproperties = {
          "hDefKey" => HKEYS[:HKEY_LOCAL_MACHINE].to_s,
          "sSubKeyName" => uninstall_key + "\\" + node.text,
          "sValueName" => key
        }
        @wsopt.properties = subproperties
        value = @wsman.invoke(@wsopt, uri, method)
        package[packagekey] = value.send(valuename.to_sym).text rescue ""
      end
      time = package["installtime"]
      if time
        # convert Windows time (20101127) to Spacewalk-time (seconds since 1.1.1970)
        t = time.to_s
        package["installtime"] = Time.local(t[0, 4], t[4, 2], t[6, 2]).to_i
      else
        package["installtime"] = Time.local(1970, "Jan", 1).to_i
      end
      package["version"] = "0" if package["version"].empty?
      package["release"] = "0" if package["release"].empty?
      packages << package
    end
    
    packages
  end
  
  def bios
    puts "Checking the BIOS"
    uri = "http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/"
    klass = "Win32_BIOS"
    result = @wsman.enumerate(@wsopt, nil, uri + klass)
    bios = result.body.EnumerateResponse.Items.send(klass.to_sym)
#    dump klass, result
    return nil unless bios.SMBIOSPresent.to_s == "true"
    result = {}
#    result["smbios.bios.vendor"] = bios.
    result["smbios.system.serial"] = bios.SerialNumber
    result["smbios.system.manufacturer"] = bios.Manufacturer
    result["smbios.system.product"] = bios.Name
#    result["smbios.system.uuid"] = 
    result
  end

  #
  # Get (enabled) network interfaces
  #
  # Return hash of hashes { "<if-name>" : { ... }, ... }
  #
  def network(only_enabled=true)
    netinterfaces = nil
    puts "Enumerating network configurations"
    uri = "http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/"
    klass = "Win32_NetworkAdapterConfiguration"
    result = @wsman.enumerate(@wsopt, nil, uri + klass)
    result.Items.each do |node|
      if only_enabled
        next unless node.IPEnabled.to_s == "true"
      end
      unless @data["DNSDomain"]
        @data["DNSDomain"] = node.DNSDomain.text
      end
      unless @data["DNSHostName"]
        @data["DNSHostName"] = node.DNSHostName.text
      end
      unless @data["IPAddress"]
        @data["IPAddress"] = node.IPAddress.text
      end
      netinterfaces ||= {}
      netinterfaces["net#{node.Index}"] = { 
        'hwaddr' => node.MACAddress.text,
        'module' => node.ServiceName.text,
        'broadcast' => "255.255.255.255", # FIXME, compute from ip+subnet
        'ipaddr' => node.IPAddress.text,
        'netmask' => node.IPSubnet.text
      }
    end
    netinterfaces
  end

  #
  # Get Hardware as List of Hashes
  #
  def hardware
    hw = []
    if @data["TotalPhysicalMemory"]
      hw << { "class" => "memory", "ram" => (@data["TotalPhysicalMemory"].to_i / (1024 * 1024)).to_s }
    end
    net_if = network
    if @data["DNSHostName"] && @data["DNSDomain"] && @data["IPAddress"]
      hw << { "class" => "netinfo",
              "hostname" => @data["DNSHostName"] + "." + @data["DNSDomain"].split(" ").first,
              "ipaddr" => @data["IPAddress"]
            }
    end

    # enum Win32_SystemDevices
    # then get CIM_LogicalDevice    REF PartComponent;
    puts "Enumerating system devices"
    uri = "http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/"
    klass = "Win32_SystemDevices"
    result = @wsman.enumerate(@wsopt, nil, uri + klass)
#    dump klass, result
    # extract
    # <p:PartComponent>
    #   <a:Address>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</a:Address>
    #   <a:ReferenceParameters>
    #     <w:ResourceURI>http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/Win32_Volume</w:ResourceURI>
    #     <w:SelectorSet>
    #       <w:Selector Name="DeviceID">\\?\Volume{a8d5bad7-2709-11e1-9267-806e6f6e6963}\</w:Selector>
    #     </w:SelectorSet>
    #   </a:ReferenceParameters>
    # </p:PartComponent>
    count = 0
    result.Items.each do |device|
      count += 1
      part = device.PartComponent
      next unless part
      uri = part.ResourceURI.text
      selectors = {}
      part.SelectorSet.each do |sel|
        selectors[sel.attr.to_s] = CGI::escapeHTML(sel.text)
      end
      @wsopt.selectors = selectors
      #
      # Get device
      #
      result = @wsman.get(@wsopt, uri)
      if result.nil? || result.fault?
        STDERR.puts "Can't get #{uri}:#{selectors['DeviceID'].split('')}"
        next
      end
      result.body.each do |node|
        case node.name
        when "Win32_Processor"
          hw << { "class" => "cpu",
            'architecture' => (node.Architecture.text == "9") ? "x86_64" : "i686",
            'family' => node.Family.text,
            'mhz' => node.MaxClockSpeed.text,
            'stepping' => node.Stepping.text,
            'model' => node.Name.text,
            'vendor' => node.Manufacturer.text,
            'nrcpu' => result.body.size("Win32_Processor")
          }
        when "Win32_NetworkAdapter"
        when "Win32_PnPEntity"
        else
          STDERR.puts "Unhandled #{node.name}"
        end
      end
      if net_if
        hw << net_if.merge({ 'class' => "netinterfaces" })
      end
    end
    
    @wsopt.selectors = {}
    puts "#{count} devices"
    hw
  end

  def profile

    begin
      puts "Asking for operating system"
      uri = "http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/"
      klass = "Win32_OperatingSystem"
      result = @wsman.enumerate(@wsopt, nil, uri + klass)
#      dump klass, result
#    puts result.to_xml
      os = result.body.EnumerateResponse.Items.send(klass.to_sym)
    # debug
    # puts klass
    # os.each do |node|
    #  puts "  #{node.name}:\t#{node.text}"
    # end
  
      puts "Asking for computer system"
      klass = "Win32_ComputerSystem"
      result = @wsman.enumerate(@wsopt, nil, uri + klass)
#      dump klass, result
      hw = result.body.EnumerateResponse.Items.send(klass.to_sym)
      @data["TotalPhysicalMemory"] = hw.TotalPhysicalMemory.text
    # debug
    # puts klass
    # hw.each do |node|
    #  puts "  #{node.name}:\t#{node.text}"
    # end

    rescue
      STDERR.puts "EnumerateResponse failed for #{klass}"
      fault result
      return {}
    end
    
    puts "Assembling Windows profile"

    # assemble registration information

    data = {}
    data["os_release"] = os.CSDVersion.text
    puts "OS Release #{os.CSDVersion.text}"
    data["release_name"] = os.Caption.text
    puts "Release name #{os.Caption.text}"
    data["architecture"] = case os.OSType.text.to_i
      when 18 then "x86-microsoft-windows" # normalize architecture
      else
        STDERR.puts "Can't map #{os.OSType} to a known value"
        "x86-microsoft-windows"
      end
    puts "Windows.profile: #{data.inspect}"
    data
  end

end # windows
