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

#/*
# * To change this template, choose Tools | Templates
# * and open the template in the editor.
# */
#package viewpane;
#
#import java.util.*;
#import javafx.beans.property.DoubleProperty;
#import javafx.beans.property.SimpleDoubleProperty;
#import javafx.geometry.HPos;
#import javafx.geometry.Insets;
#import javafx.geometry.Orientation;
#import javafx.geometry.VPos;
#import javafx.scene.*;
#import javafx.scene.layout.*;
#import javafx.util.Pair;

class SD::Utils::TitledFormPane < Java::javafx.scene.layout.Pane
  include JRubyFX

	EXPAND_TAG = "titled-form-pane-expand"

  fxml_accessor :hgap, SimpleDoubleProperty
  fxml_accessor :maxRightWidth, SimpleDoubleProperty

  def self.setExpand(child, value)
		setConstraint(child, EXPAND_TAG, value)
  end

	def self.getExpand(child)
		true == getConstraint(child, EXPAND_TAG)
  end

  def getExpand(child)
    self.class.getExpand(child)
  end

	def computePrefWidth(d)
		layoutChildren?(false)
		return @lastWidth
  end

	def computePrefHeight(d)
		return d
  end

	def layoutChildren()
		layoutChildren?(true)
  end

	def layoutChildren?(actualLayout)
		managed = getManagedChildren()
		insets = getInsets()
		width = getWidth()
    height = getHeight()
		height = getPrefHeight() if height < 1.9

		top = snapSpace(insets.top)
    left = snapSpace(insets.left)
    bottom = snapSpace(insets.bottom)
    right = snapSpace(insets.right)
		height = [2, height - top - bottom].max

		itemHeight = []
		managed.each do |node|
			itemHeight << computeChildPrefAreaHeight(node, Insets::EMPTY, -1)
    end
    itemHeight = itemHeight.max || 12

    # now build up columns
    cols = []
		colLength = (height / itemHeight * 2).floor
		col = [[],[]]
		onLeft = true
		length = 0

		managed.each { |node|
			if (onLeft)
				if (getExpand(node))
          if (length + 3 >= colLength)
            # are we the last item? if so, bump to next row
            cols << col
            col = [[],[]]
            length = 0
          end
          length +=1
					onLeft = false
					col[1] << nil
        end
				length +=1
        col[0] << node
      else
				length+=1
				if (getExpand(node))
					puts("Warning: Unbalanced tree in TitledFormPane")
					length += 2
					onLeft = false
					col[1] << nil
					col[1] << nil
					col[0] << node
				else
					col[1] << node
        end
      end
			if (length + 1 >= colLength && !onLeft)
				cols << col
				col = [[],[]]
				length = 0
      end
			onLeft ^= true
    }
		cols << col if col[0].length > 0
		numCols = 2 * cols.length
		widths = []
    # computes ths widths of the columns
		cols.each do |pair|
      onLeft = true
			pair.each do |tmp|
				wmax = [0]
        tmp.each do |node|
          wmax << computeChildPrefAreaWidth(node, Insets::EMPTY, -1) if node
        end
        maxr = getMaxRightWidth || Float::MAX
        maxr = Float::MAX if onLeft or maxr < 1
				widths << [wmax.max, maxr].min
        onLeft = false
      end
    end
		#now we can set stuff
		j = 0
		prefixX = left
		cols.each do |pair|
      i = 0
			pair.each do |tmp|
				prefixY = top
				wmax = widths[j]
				tmp.each do |node|
					if (actualLayout && node)
						#TODO: check bounds?
						layoutInArea(node, prefixX, prefixY, getExpand(node) ? wmax + widths[j+1] : wmax, itemHeight, itemHeight, Insets::EMPTY, defaultHPos(i, node), VPos::CENTER)
          end
					#node.resizeRelocate(prefixX, prefixY, wmax, itemHeight)
					prefixY += itemHeight
        end
				prefixX += wmax + (getHgap() || 0)
				j+=1
        i+=1
      end
    end

    prefixX -= (getHgap()||0) if cols.length > 1
		@lastWidth = prefixX + right
  end

	def defaultHPos(i, node)
    eResult = GridPane.getHalignment(node) == nil ? HPos::LEFT : GridPane.getHalignment(node);
		if i == 0
			getExpand(node) ? eResult : HPos::RIGHT;
    else
      eResult
    end
  end

	def getContentBias()
		return Orientation::VERTICAL
  end

	# manually copied from JFX sources since they are package private stupidly
	def computeChildPrefAreaWidth( child,  margin,  height)

    top = margin != nil ? snapSpace(margin.top) : 0;
    bottom = margin != nil ? snapSpace(margin.bottom) : 0;
    left = margin != nil ? snapSpace(margin.left) : 0;
    right = margin != nil ? snapSpace(margin.right) : 0;
    alt = -1;
		if (child.getContentBias() == Orientation::VERTICAL)
      # width depends on height
      alt = snapSize(boundedSize(height != -1 ? height - top - bottom
          : child.prefHeight(-1), child.minHeight(-1), child.maxHeight(-1)));
    end
    return left + snapSize(boundedSize(child.prefWidth(alt), child.minWidth(alt), child.maxWidth(alt))) + right;
  end

  def computeChildPrefAreaHeight(child,margin, width)
    top = margin != nil ? snapSpace(margin.getTop()) : 0;
    bottom = margin != nil ? snapSpace(margin.getBottom()) : 0;
    left = margin != nil ? snapSpace(margin.getLeft()) : 0;
    right = margin != nil ? snapSpace(margin.getRight()) : 0;
    alt = -1;
    if (child.getContentBias() == Orientation::HORIZONTAL)
      # width depends on height
      alt = snapSize(boundedSize(width != -1 ? width - left - right
          : child.prefWidth(-1), child.minWidth(-1), child.maxWidth(-1)));
    end
    return top + snapSize(boundedSize(child.prefHeight(alt), child.minHeight(alt), child.maxHeight(alt))) + bottom;
  end

  def boundedSize( value,  min,  max)
    # if max < value, return max
    # if min > value, return min
    # if min > max, return min
    return [[value, min].max, [min, max].max].min
  end

  def self.setConstraint(paramNode, paramObject1, paramObject2)

    if (paramObject2 == nil)
      paramNode.getProperties().remove(paramObject1);
    else

      paramNode.getProperties().put(paramObject1, paramObject2);
    end
    if (paramNode.getParent() != nil)
      paramNode.getParent().requestLayout();
    end
  end

  def self.getConstraint(paramNode, paramObject)
    if (paramNode.hasProperties())
      return paramNode.getProperties().get(paramObject)
    end
  end
end
