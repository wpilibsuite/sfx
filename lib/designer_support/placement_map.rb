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

class SD::DesignerSupport::PlacementMap
  def initialize(block_size, width, height)
    @bsize = block_size
    @width = width
    @height = height
    @continuous = false
    @occupancy_grid = (1..(width / block_size).ceil).map{ (1..(height/ block_size).ceil).map{false} }
  end

  def occupy_block(x, y, value=true)
    @continuous = false
    if (0..(@height/@bsize - 1).ceil).include?(y) && (0..(@width/@bsize - 1).ceil).include?(x)
      @occupancy_grid[x][y] = value
    else
      raise "Out of bounds!"
    end
  end

  def continuous?
    @continuous
  end

  def occupy_point(x, y, value=true)
    occupy_block((x/@bsize).ceil, (y/@bsize).ceil, value)
  end

  def block_occupied?(x, y)
    @occupancy_grid[x][y]
  end

  def occupy_rectangle(min_x, max_x, min_y, max_y, value=true)
    min_x = (min_x / @bsize).floor
    min_y = (min_y / @bsize).floor
    max_x = (max_x / @bsize).ceil
    max_y = (max_y / @bsize).ceil

    min_x.upto(max_x) do |x|
      min_y.upto(max_y) do |y|
        occupy_block(x, y, value)
      end
    end
  end

  def random_place(width, height)
    width = (width/@bsize).ceil
    height = (height/@bsize).ceil

  end

  def area
    @occupancy_grid.map{|c| c.find_all{|i| i}}.flatten.length
  end

  def invert!
    @occupancy_grid.map! { |col| col.map{|i| !i} }
  end

  def split
    splits = []
    tmp_grid = @occupancy_grid.map{|col| col.clone }
    while tmp_grid.index {|col| y = col.index(true)}
      split_grid = @occupancy_grid.map{|col| col.map{|i| false } }
      # find the first thing
      y = 0
      x = tmp_grid.index {|col| y = col.index(true)}
      split_grid[x][y] = true
      split_around(x, y, tmp_grid, split_grid)

      (@height/@bsize).ceil.times do |y|
        (@width/@bsize).ceil.times do |x|
          tmp_grid[x][y] = false if split_grid[x][y]
        end
      end
      splits << split_grid
    end
    return splits.map do |spl|
      tmp = self.class.new(@bsize, @width, @height)
      tmp.instance_variable_set(:@occupancy_grid, spl)
      tmp.instance_variable_set(:@continuous, true)
      tmp
    end
  end

  def split_around(x, y, tmp_grid, split_grid)
    return if x < 0 or y < 0 or y >= ((@height/@bsize).ceil) or x >=(@width/@bsize).ceil
    ways = [[-1,0], [+1, 0], [0, -1], [0, +1]]
    travs = []
    ways.each do |way|
      begin
        if  x + way[0] >= 0 and  y + way[1] >= 0 and tmp_grid[x + way[0]][y+way[1]] and !split_grid[x + way[0]][y+way[1]]
          split_grid[x + way[0]][y+way[1]] = true
          travs << way
        end
      rescue
        # shh, its a bad offset, just ignore it
      end
    end
    travs.each do |way|
      split_around(x + way[0], y+way[1], tmp_grid, split_grid)
    end
  end

  def find_space(min_x, max_x, min_y, max_y)
    rectanglify
    
  end
  def stuff(min_x, max_x, min_y, max_y)
    min_x = (min_x / @bsize).floor
    min_y = (min_y / @bsize).floor
    max_x = (max_x / @bsize).ceil
    max_y = (max_y / @bsize).ceil
    rect_width = max_x - min_x
    rect_height = max_y - min_y
    rect_area = rect_width * rect_height
    # we wan't negative space, so split our inverse, then restore
    self.invert!
    splits = self.split.find_all{|spl| spl.area >= rect_area}
    self.invert!
    return nil if splits.length < 1
    splits.each do |spl|
      spl_grid = spl.instance_variable_get(:@occupancy_grid)
      heights = spl_grid.map{|col| col.max_in_a_row}
      # make sure we can fit
      next if heights.map{|i| i >= rect_height}.max_in_a_row < rect_width
      widths = spl_grid.transpose.map{|row| row.max_in_a_row}
      next if widths.map{|i| i >= rect_width}.max_in_a_row < rect_height
      # we should be able to fit in, unless its diagonal
      likely_grids = heights.map{|i| i >= rect_height}.index_in_a_row(rect_width).product(widths.map{|i| i >= rect_width}.index_in_a_row(rect_height))
      # => [[[x, length], [y, height]], ...]
      # now extract all grid locations
      likely_grids = Hash[likely_grids.map do |infopair|
          x, length, y, height = infopair.flatten
          [[x, y], spl_grid[x, length].map{|col| col[y, height]}]
        end]
      puts "Found likey grid areas:"
      p likely_grids
      likely_grids.each do |loc, grid|
        # find areas that will fit
        heights = grid.map{|col| col.max_in_a_row}
        next if heights.map{|i| i >= rect_height}.max_in_a_row < rect_width
        widths = grid.transpose.map{|row| row.max_in_a_row}
        next if widths.map{|i| i >= rect_width}.max_in_a_row < rect_height
        # hey, We think we found a spot! now we need to check for defects in the center and position ourselves around that

        y = 0
        x = grid.index {|col| y = col.index(false)}
        unless x or y
          # no defects!
          puts "Found defect free area at #{x}, #{y}"
          return [x, y]
        end
        # TODO: trim out impossible areas using heights/widths variables

      end
    end
    return nil
  end

  def to_s
    puts "-" * ((@width/@bsize).ceil * 2)
    (@height/@bsize).ceil.times do |y|
      (@width/@bsize).ceil.times do |x|
        print (@occupancy_grid[x][y] ? "x ": "  ")
      end
      puts ""
    end
    puts "-" *  ((@width/@bsize).ceil * 2)
  end
end

class Array
  def index_in_a_row(min_run=1)
    res = []
    cur = 0
    idx = 0
    self.each do |x|
      if x
        cur += 1
      else
        res << [idx - cur, cur] if cur >= min_run
        cur = 0
      end
      idx +=1
    end
    res
  end
  def max_in_a_row
    runs = [0]
    cur = 0
    self.each do |x|
      if x
        cur += 1
      else
        runs << cur if cur > 0
        cur = 0
      end
    end
    runs.max
  end
end