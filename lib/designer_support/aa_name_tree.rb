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
          if !data[:control] and (!(data[:object].group_name.nil? or data[:object].group_name.empty?) or data[:object].type)
            begin
              data[:cinfo] = if !(data[:object].group_name.nil? or data[:object].group_name.empty?)
                SD::Plugins.controls.find{|x| x.group_types == data[:object].group_name}
              else
                SD::DesignerSupport::PrefTypes.for(data[:object].type)
              end
            rescue
              puts "ahhrg"
              puts $!
              # just let it be null
            end
            if data[:cinfo]
              data[:control] = data[:cinfo].new
              data[:control].name = @name
              data[:time] = Time.now
            end
          end
          if data[:control] && parent.data[:descriptor]
            if parent.data[:descriptor].can_nest?
              data[:descriptor] = add_designable_control.call(data[:control], nil, nil, nearest_desc(data[:control]).child, data[:cinfo])
            end
            data[:in_ui] = true
          end
          if expired? && data[:control]
            original_pard = nearest_desc(data[:control])
            original_par = original_pard.child
            if original_pard.can_nest?
              data[:descriptor] = add_designable_control.call(data[:control], nil, nil, original_par, data[:cinfo])
              data[:expired_proc] = -> {
                data[:control].name = name
                par = (pard = nearest_desc(data[:control])).child
                if pard.can_nest?
                  add_designable_control.call(data[:descriptor], nil, nil, par, data[:cinfo])
                else
                  # remove when parent is sealed
                  data[:last_parent].child.children.remove(data[:descriptor])
                  data[:expired_proc] = nil
                end
                pard
              }
              data[:last_parent] = original_pard
            end
            data[:in_ui] = true
          end
        else
          if data[:expired_proc] && data[:last_parent] != nearest_desc(nil)
            data[:last_parent] = data[:expired_proc].call
          end
        end
        @children.each do |name, child|
          child.process(add_designable_control)
        end
      end

      def nearest_desc(control)
        desc = parent.data[:descriptor] || parent.nearest_desc(control)
        if desc == parent.data[:descriptor] && parent.name != "" && control
          # truncate the path
          # TODO: check if nested or passthrough
          control.name = control.name.gsub(%r{^#{parent.name}/?}, "")
        end
        desc
      end
      def expired?
        Time.now - data[:time] > 0.5
      end
      def self.observable=(obs)
        @@observable = obs
      end

      def to_s(nest="")
        childs = children.map{|k, x|x.to_s(nest + " ")}.join("\n" + nest)
        bits = "#{data[:in_ui] ? "ui" : ""} #{data[:control] ? "control" : "" } #{parent.data[:descriptor] ? "parent" : "" }"
        "#{nest}#{name} ;; #{bits} -- #{parent.data[:descriptor].inspect}#{childs.length > 0 ? "\n#{nest}" : "" } #{childs}"
      end
    end
  end
end
