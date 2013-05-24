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

class SD::DesignerSupport::PrefTypes
  def self.create_toolbox(parts, prefs)
    @std_parts = parts[:standard]
    @prefs = prefs
  end
  def self.for(enum)
    svt = Java::dashfx.data.SmartValueTypes
    floats = ints = nums = @std_parts.find{|x|x["Name"] == @prefs.get("defaults_type_number", "Bad Slider")}[:proc]
    map = {
      svt::Double.mask => floats,
      svt::Float.mask => floats,
      svt::Integer.mask => ints,
      svt::Number.mask => nums,
    }
    map[enum.mask].call
  end
end
