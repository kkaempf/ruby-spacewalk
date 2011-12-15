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

    require "xmlrpc/client"
    require 'uri'
    require 'zlib'
    require 'base64'
    require 'rexml/document'

private
    def call name, *args
#      puts "Call #{name}(#{args.inspect})"
      result = @client.call(name, *args) rescue nil

      response = @client.http_last_response
      raise "XMLRPC failed with #{response.code}" unless response.code == "200"
      body = response.body
      case response["content-type"]
      when "text/base64"
	body = Base64.decode64(body)
      when "text/xml"
	# fallthru
      else
        STDERR.puts "Unhandled content-type #{response['content-type']}"	
      end
      case response["content-encoding"]
      when "x-zlib"
	body = Zlib::Inflate.inflate(body)
      when nil
	# fallthru
      else
	STDERR.puts "Unhandled content-encoding #{response['content-encoding']}"
      end
      ok, result = @client.get_parser.parseMethodResponse(body)
      raise unless ok
      result
    end
public

    def initialize
      @config = Spacewalk::Config.new

      uri = URI.parse(@config.serverurl)
      args = {:host=>uri.host, :path => uri.path, :use_ssl => (uri.scheme == "https")}
      if @config.httpProxy
	args[:proxy_host], clientargs[:proxy_port] = @config.httpProxy.split ":"
      end

      @client = XMLRPC::Client.new_from_hash args

      @client.http_header_extra = {}

      welcome
      
      # parse server capabilities
      @capabilities = Spacewalk::Capabilities.new @client
			      
      @client.http_header_extra["X-Up2date-Version"] = "1.6.42" # from rhn-client-tools.spec
				  
      @systemid = Spacewalk::SystemId.new @client, @config

      # check for distribution update
#      my_id = @systemid.os_release
#      server_id = osversion

    end
    
    # welcome to/from server
    def welcome
      result = call "registration.welcome_message"
      puts "Welcome => #{result.inspect}"
    end
    
    # get system O/S version
    def osversion
      result = @config.versionOverride
      unless result
	# find rpm provider of redhat-release or distribution-release, get its version
      end
      result
    end
    
    def actions
      report = Spacewalk::StatusReport.status

      result = call "queue.get", @systemid.to_xml, ACTION_VERSION, report
      puts "Actions => #{result.inspect}"
      
      if action = result["action"]
	result["action"] = @client.get_parser.parseMethodCall(action)
      end      
      puts "Actions => #{result.inspect}"
    end
  end
end
