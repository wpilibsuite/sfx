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

module SD
  module Plugins
    class PluginInfo
      REQUIRED_FIELDS = %W[API Name Version Plugin\ ID]
      OPTIONAL_FIELDS = {
        "Description" => "", # name,  default value
        "Controls" => [],
      }
      attr_reader :location, *((REQUIRED_FIELDS + OPTIONAL_FIELDS.keys).map {|name| name.downcase.gsub(" ", "_")})
      def initialize(location, info)
        @location = location
        info = Hash[info.map{|k,v| [k.to_s, v]}]
        REQUIRED_FIELDS.each do |rf|
          raise ArgumentError.new("Required field '#{rf}' not found in plugin manifest") unless info.has_key?(rf)
          instance_variable_set("@#{rf.downcase.gsub(" ", "_")}", info[rf])
        end
        OPTIONAL_FIELDS.each do |of, default|
          instance_variable_set("@#{of.downcase.gsub(" ", "_")}", info[of] || default)
        end
      end
    end
  end
end
