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
      @smart_value = nil

      def self.parse_prefs
        props = SD::DesignerSupport::Preferences
        tmp = props.aa_policy
        # TODO: exceptions in parsing

        @regex, @code = case tmp
        when "never"
          [nil, nil]
        when "regex"
          regex = props.aa_regex
          if regex == ""
            puts "Warning: Empty AutoAdd regex, disabling regex matching. Go to settings and enter a non-empty regex under AutoAdd"
            [nil, nil]
          else
            [Regexp.new(regex), nil]
          end
        when "code"
          [nil, SD::DesignerSupport::AACodeFilter.init(props.aa_code)]
        end
      end

      def self.have_code?
        @code != nil
      end

      def self.have_regex?
        @regex != nil
      end

      def self.regex=(regex)
        @regex = regex
      end

      def self.regex
        @regex
      end

      def self.filter(name, all_names)
        return true if @always_add
        if have_regex?
          return name.match(@regex) != nil
        elsif have_code?
          return @code.should_add?(name, all_names)
        end
        return false
      end

      def self.always_add=(value)
        @always_add = value
      end

      def self.always_add
        @always_add == true
      end

      def self.smart_value(name)
        @smart_value.call(name)
      end

      def self.on_smart_value(&block)
        @smart_value = block
      end
    end

    # TODO: seems non-optimal
    class AACodeFilter
      def self.init(code)
        tmp = self.new
        tmp.instance_eval <<ELL
        def should_add?(new, all)
#{code}
        end
ELL
        tmp
      end
      # def should_add?(new, all)
    end
  end
end
