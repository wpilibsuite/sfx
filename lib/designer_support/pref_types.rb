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
  def self.create_toolbox(all)
    # TODO: save this as all possible controls
  end
  def self.for(enum)
    svt = Java::dashfx.data.SmartValueTypes
    map = {
      svt::Double.mask => Java::dashfx.controls.BadSliderControl,
      svt::Float.mask => Java::dashfx.controls.BadSliderControl,
      svt::Integer.mask => Java::dashfx.controls.BadSliderControl,
      svt::Number.mask => Java::dashfx.controls.BadSliderControl,
    }
    map[enum.mask]
  end
end
