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
  module Windowing
    class LayoutManager
      include JRubyFX
      def initialize(root)
        @root = root
        @children = {}
        @thread = false
      end

      # requires {child =>[x, y], child => nil} style
      # first places, second finds
      def layout_controls(children_map)
        @root.synchronized do
          @children.merge! children_map
          if @root.appendable?
            children_map.each do |child, (x, y)|
              @root.add_child_at child, x||0, y||0
            end
          else
            @root.children.add_all children_map.keys
            children_map.keys.each {|c| @root.add_control c} #TODO: should not need to do this
            @has_nils ||= children_map.values.include?([nil,nil])
            unless @thread
              @thread = Thread.new &method(:thread_run)
            end
          end
        end
      end

      def thread_run
        begin
          sleep(0.05) # wait for layout passes
        end while @root.ui.height < 1
        run_later do
          @root.synchronized do
            # get a placement map if we need one (Aka we cant just append the item)
            fmap = if @has_nils
              SD::DesignerSupport::PlacementMap.new(10, @root.ui.width, @root.ui.height).tap do |pm|
                # add all the current children to the occupancy map
                @root.children.each do |child|
                  bip = child.bounds_in_parent
                  # don't add "hidden" ones
                  pm.occupy_rectangle(bip.min_x, bip.max_x, bip.min_y, bip.max_y) unless bip.min_y == 0 and bip.min_x == 0
                end
              end
            end
            @children.each do |itm, (x, y)|
              next unless itm
              @root.ui.layout
              x, y = unless x or y
                # do a brute force search on spaces that fit
                catch :done do
                  0.step(@root.ui.width, 10) do |x|
                    0.step(@root.ui.height, 10) do |y|
                      throw(:done, [x,y]) unless fmap.rect_occupied?(x, x+itm.width, y, y+itm.height)
                    end
                  end
                end
              else
                # just center it
                bip = itm.bounds_in_parent
                [x - (bip.width / 2).to_i, y - (bip.height / 2).to_i]
              end
              # once we find a location, place the control at that location and mask it off in the map
              itm.layout_x = x
              itm.layout_y = y
              if fmap
                bip = itm.bounds_in_parent
                fmap.occupy_rectangle(x, bip.width + x, y, y + bip.height)
              end
            end
          end
          @thread = false
          @children = {}
          @has_nils = false
        end
      end
    end
  end
end
