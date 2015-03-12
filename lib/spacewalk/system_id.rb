module Spacewalk
  class SystemId
    require 'xmlrpc/client'
    def initialize(client, config)
      fail "Expecting a Spacewalk::Config parameter to #{self.class}.new" unless config.is_a?(Spacewalk::Config)
      @path = config["systemIdPath"]
      fail "systemIdPath is empty !" unless @path
      # <params>
      #   <param>
      #     <value>
      #       <struct>
      #         <member>
      #           <name>username</name>
      #           <value><string>admin</string></value>
      #         </member>
      File.open(@path) do |f|
	@raw = f.read
	@members = client.get_parser.parseMethodResponse(@raw)
      end
      puts "SystemId => #{@members.inspect}"
    end

    def to_xml
      @raw
    end
  end
end