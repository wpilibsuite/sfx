# Copyright (C) 2013 patrick
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
require 'cgi'

module SD
  module Utils
    class Url
      include JRubyFX::DSL
      property_accessor :name, :class_name, :host, :port, :mount, :options

      URL_REGEX = /dashfx:\/\/(?<class_name>[\w\.:]+)@(?<host>[^:]*)(:(?<port>[0-9]*))?(?<mount>\/([\w\+%]*))(\?(?<args>.*))?/
      MAGIC_HOST = "xn--mxam4bc95czbc7b6hubbgd"

      def initialize(name, clazz, host, port, mount, options={})
        @name = simple_string_property(self, "name", name)
        @class_name = simple_string_property(self, "className", "Java::#{clazz.java_class.name}") # TODO: nested classes
        @host = simple_string_property(self, "host", (host.nil? or host.empty? or host == MAGIC_HOST) ? nil : host)
        @port = simple_integer_property(self, "port", (port.nil? or port == "") ? 0 : port.to_i)
        @mount = simple_string_property(self, "mount", mount)
      end

      def find_class
        unless @saved_class
          @saved_class = eval(class_name) # TODO: use constantize
        end
        @saved_class
      end

      def to_did
        iii = build(Java::dashfx.lib.data.InitInfo, host: host, port: port)
        # TODO: options
        Java::dashfx.lib.data.DataInitDescriptor.new(find_class.new, name, iii, mount)
      end

      def to_s
        @str = "dashfx://#{class_name}@#{(host.nil? or host.empty?) ? MAGIC_HOST : host}:#{port}#{mount}"
        unless true # @options.empty?
          @str << "?#{@options.map{|x| raise "TODO"}.join("&")}"
        end
        return @str
      end

      def self.parse(url, name=nil)
        m = URL_REGEX.match(url)
        # TODO: parse options
        new(name || m[:class_name].split(".").last, m[:class_name], m[:host], m[:port], m[:mount], m[:options])
      end
      def self.from(did)
        name = did.name
        obj = did.object
        iii = did.init_info
        mount = did.mount_point
        port = iii.port
        host = iii.raw_host
        opts = iii.all_options
        new name, obj.class, host, port, mount, opts
      end
    end
  end
end
