module XMLRPC
  class Client
    def get_parser
      parser
    end
  end
end

module Spacewalk
  class Server
    # from /usr/sbin/rhn_check
    # action version we understand
    ACTION_VERSION = 2

    require 'xmlrpc/client'
    require 'openssl'
    require 'uri'
    require 'zlib'
    require 'base64'
    require 'rexml/document'

    private
    def call(name, *args)
#      puts "Call #{name}(#{args.inspect})"
      begin
	# remove trailing nil values, nil is not supported in xmlrpc
	args.pop while args.size > 0 && args[-1].nil?
	result = @client.call(name, *args)
      rescue StandardError => e
	raise e unless e.message =~ /Wrong content-type/
      end
      response = @client.http_last_response
      fail "XMLRPC failed with #{response.code}" unless response.code == '200'
      body = response.body
      case response['content-type']
      when 'text/base64'
	body = Base64.decode64(body)
      when 'text/xml'
	# fallthru
      else
        STDERR.puts "Unhandled content-type #{response['content-type']}"
      end
      case response['content-encoding']
      when 'x-zlib'
	body = Zlib::Inflate.inflate(body)
      when nil
	# fallthru
      else
	STDERR.puts "Unhandled content-encoding #{response['content-encoding']}"
      end
      ok, result = @client.get_parser.parseMethodResponse(body)
      fail unless ok
      result
    end
    public

    #
    # Initialize server xmlrpc port
    # options:
    #  :noconfig => true - don't load @config
    #  :server => string - url of server (for initial registration)
    #  :systemid => string
    #
    def initialize(options = {})
      @config = Spacewalk::Config.new
      if options[:noconfig]
	uri = URI.parse(options[:server])
 fail "Server '#{options[:server]}' is not proper URL" unless uri.host
	uri.path = '/XMLRPC'
      else
	uri = URI.parse(@config.serverurl)
      end

      args = {:host => uri.host, :path => uri.path, :use_ssl => (uri.scheme == 'https'), :timeout => 120 }

      unless options[:noconfig]
	if @config.httpProxy
	  args[:proxy_host], clientargs[:proxy_port] = @config.httpProxy.split ':'
	end
      end

      @client = XMLRPC::Client.new_from_hash args

      @client.http_header_extra = {}
      @client.instance_variable_get('@http').verify_mode = OpenSSL::SSL::VERIFY_NONE
      welcome

      # parse server capabilities
      @capabilities = Spacewalk::Capabilities.new @client

      @client.http_header_extra['X-Up2date-Version'] = '1.6.42' # from rhn-client-tools.spec
      @client.http_header_extra['X-RHN-Client-Capability'] = 'packages.extended_profile(2)=1'
      @systemid = options[:systemid]
      unless @systemid || options[:noconfig]
        @systemid = Spacewalk::SystemId.new(@client, @config).to_xml
      end
      # check for distribution update
#      my_id = @systemid.os_release
#      server_id = osversion

    end

    # welcome to/from server
    def welcome
      result = call 'registration.welcome_message'
#      puts "Welcome => #{result.inspect}"
    end

    # get system O/S version
    def osversion
      result = @config.versionOverride
      unless result
	# find rpm provider of redhat-release or distribution-release, get its version
      end
      result
    end
    #
    # get immediately pending actions
    #
    def actions
      report = Spacewalk::StatusReport.status
#      puts "report => #{report.inspect}"
#      puts "@systemid => #{@systemid.inspect}"

      result = call 'queue.get', @systemid, ACTION_VERSION, report
#      puts "queue.get  => #{result.inspect}"

      action = result['action']
      if action
	result['action'] = @client.get_parser.parseMethodCall(action)
      end
#      puts "Actions => #{result.inspect}"
    end
    #
    # get future actions
    #   needs "staging_content" server capability
    #
    # time_window: (int) number of hours to look forward
    #
    def future_actions(time_window)
      time_window = time_window.to_i unless time_window.is_a? Fixnum
      report = Spacewalk::StatusReport.status
#      puts "future_actions #{time_window}"

      results = call 'queue.get_future_actions', @systemid, time_window
#      puts "queue.get_future_actions  => #{results.inspect}"
      results.map! do |result|
        action = result['action']
        if action
          result['action'] = @client.get_parser.parseMethodCall(action)
        end
        result
      end
#      puts "Future actions => #{results.inspect}"
      results
    end
    #
    # submit action result back to server
    #
    def submit_response(action_id, status, message, data)
      fail 'Data must be hash' unless data.is_a? Hash
      result = call 'queue.submit', @systemid, action_id, status, message, data
    end
    #
    # register with activation key
    # profile_name is hash of "os_release" => version, "release_name" => name, "architecture" => arch }
    #
    def register(activationkey, profile_name, other = {})
      auth_dict = {}
      auth_dict['profile_name'] = profile_name
      # dict of other bits to send
      auth_dict.update other
      auth_dict['token'] = activationkey
      # auth_dict["username"] = username
      # auth_dict["password"] = password

      # if cfg['supportsSMBIOS']:
      #	auth_dict["smbios"] = _encode_characters(hardware.get_smbios())
#      STDERR.puts "registration.new_system #{auth_dict.inspect}"
      @systemid = call 'registration.new_system', auth_dict
    end
    #
    # send package list to server
    #
    def send_packages(packages)
      call 'registration.add_packages', @systemid, packages
    end
    #
    # send hardware details to server
    #
    def refresh_hardware(devices)
      call 'registration.refresh_hw_profile', @systemid, devices
    end
  end
end
