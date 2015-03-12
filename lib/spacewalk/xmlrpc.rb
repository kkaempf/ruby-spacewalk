module Spacewalk
  class Xmlrpc
    require 'rexml/document'

    def self.value2ruby(element)
      puts "value2ruby element #{element}"
      node = element[0]
      puts "value2ruby node #{node}"
      case node.name
      when 'string'
        node.text
      when 'struct'
        fail 'value2ruby: <member> not following <struct>' unless node[0].name == 'member'
        value = {}
        puts "Struct #{node}"
        node.each_element('member') do |e|
          name = e.elements['member/name'].text
          v = value2ruby m.elements['member/value']
          value[name] = v
        end
        value
      when 'array'
        fail 'value2ruby: <data> not following <array>' unless node[0].name == 'data'
        value = []
#       puts "Array #{node}"
        node.each_element('data/value') do |e|
#         puts "recursive #{e}"
          value << value2ruby(e)
        end
        value
      else
        fail "value2ruby: Can't handle element '#{element.name}'"
      end
    end

      # <params>
      #   <param>
      #     <value>
      #       <struct>
      #         <member>
      #           <name>username</name>
      #           <value><string>admin</string></value>
      #         </member>
      #     <value><string>...
      #     <value><array><data>...
      #
    def self.decode(_what)
      @doc.root.elements['params/param']

      initialize config
      fail "Expecting a Spacewalk::Config parameter to #{self.class}.new" unless config.is_a?(Spacewalk::Config)
      @path = config['systemIdPath']
      fail 'systemIdPath is empty !' unless @path
      @doc = REXML::Document.new(File.open(@path))
      @members = @doc.root.elements['params/param']
    end
  end
end
