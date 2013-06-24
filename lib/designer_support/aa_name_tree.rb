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
    class AANameTree
      attr_accessor :name, :children, :parent, :data
      def initialize(name, parent)
        @name = name
        @children = {}
        @parent = parent
        @data = {time: Time.now, object: @@observable.call(name)}
      end
      def process(add_designable_control)
        unless data[:in_ui]
          unless data[:control] or data[:object].group_name.nil? or data[:object].group_name.empty?
            data[:control] = SD::Plugins::controls.find{|x|x.group_types == data[:object].group_name}.tap{|x|data[:cinfo] = x}.new
            data[:control].name = @name
            data[:time] = Time.now
          end

          if data[:control] && parent.data[:descriptor]
            if parent.data[:descriptor].can_nest?
              data[:descriptor] = add_designable_control.call(data[:control], nil, nil, parent.data[:descriptor], data[:cinfo])
            end
            data[:in_ui] = true
          end
          if expired? && data[:control]
            p data[:control]
            data[:descriptor] = add_designable_control.call(data[:control], nil, nil, nearest_desc, data[:cinfo])
            data[:in_ui] = true
          end
        end
        @children.each do |name, child|
          child.process(add_designable_control)
        end
      end

      def nearest_desc
        parent.data[:descriptor] || parent.nearest_desc
      end
      def expired?
        Time.now - data[:time] > 0.02
      end
      def self.observable=(obs)
        @@observable = obs
      end
    end
  end
end
