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

class NilPoint
  def x
    0
  end
  def y
    0
  end
  def fixed
    false
  end
  def empty?
    true
  end
  def to_a
    [x, y]
  end
  def to_ary
    [x, y]
  end
end

class MousePoint
  attr_reader :x, :y, :fixed
  def initialize(x, y, compute=true)
    @x, @y, @fixed = x, y, !compute
  end
  def empty?
    false
  end
  def to_a
    [x, y]
  end
  def to_ary
    [x, y]
  end
end