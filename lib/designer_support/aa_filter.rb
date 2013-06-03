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
  module DesignerSupport
    class AAFilter
      @filtered = false
      @smart_value = nil
      @have_regex = false

      def self.parse(props)
        tmp = props.get("aa_policy", "never")
        @filtered, @have_regex = case tmp
        when "never"
          [false, false]
        when "regex"
          @regex = props.get("aa_regex", "")
          if @regex == ""
            puts "Warning: Empty AutoAdd regex, disabling regex matching. Go to settings and enter a non-empty regex under AutoAdd"
            [false, false]
          else
            [true, true]
          end
        when "code" # TODO: this
          [true, false]
        end
      end

      def self.filtered?
        @filtered
      end
      def self.have_regex?
        @have_regex
      end

      def self.filter(name, all_names)
        return false unless filtered?
        if have_regex?
          return name.match(Regexp.new(@regex)) != nil
        end
        # TODO: do more
        false
      end

      def self.smart_value(name)
        @smart_value.call(name)
      end

      def self.on_smart_value(&block)
        @smart_value = block
      end
    end
  end
end
