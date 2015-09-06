/*
 * Copyright (C) 2015 patrick
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package edu.wpi.first.sfx.designer.ui;

import java.util.ArrayList;
import java.util.List;
import javafx.beans.property.DoubleProperty;
import javafx.beans.property.SimpleDoubleProperty;
import javafx.geometry.HPos;
import javafx.geometry.Insets;
import javafx.geometry.Orientation;
import javafx.geometry.VPos;
import javafx.scene.Node;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.Pane;

/**
 *
 * @author patrick
 */
public class TitledFormPane extends Pane
{

	private static final String EXPAND_TAG = "jtitled-form-pane-expand";

	private SimpleDoubleProperty hgap_ = new SimpleDoubleProperty(0);

	public double getHgap()
	{
		return hgap_.doubleValue();
	}

	public void setHgap(double value)
	{
		hgap_.setValue(value);
	}

	public DoubleProperty hgapProperty()
	{
		return hgap_;
	}

	private SimpleDoubleProperty maxRightWidth_ = new SimpleDoubleProperty(Double.MAX_VALUE);

	public double getMaxRightWidth()
	{
		return maxRightWidth_.doubleValue();
	}

	public void setMaxRightWidth(double value)
	{
		maxRightWidth_.setValue(value);
	}

	public DoubleProperty maxRightWidthProperty()
	{
		return maxRightWidth_;
	}

	static public void setExpand(Node child, boolean value)
	{
		setConstraint(child, EXPAND_TAG, value);
	}

	static public boolean getExpand(Node child)
	{
		Boolean bol = (Boolean) getConstraint(child, EXPAND_TAG);
		if (bol == null)
			return false;
		return true == bol;
	}
	private double lastWidth;

	@Override
	protected double computePrefWidth(double d)
	{
		layoutChildren_(false);
		return this.lastWidth;
	}

	@Override
	protected double computePrefHeight(double d)
	{
		return d;
	}

	public void layoutChildren()
	{
		layoutChildren_(true);
	}

	private void layoutChildren_(boolean actualLayout)
	{
		List<Node> managed = getManagedChildren();
		Insets insets = getInsets();
		double width = getWidth();
		double height = getHeight();
		if (height < 1.9)
		{
			height = getPrefHeight();
		}

		double top = snapSpace(insets.getTop());
		double left = snapSpace(insets.getLeft());
		double bottom = snapSpace(insets.getBottom());
		double right = snapSpace(insets.getRight());
		height = Math.max(2, height - top - bottom);

		final ArrayList<Double> itemHeight = new ArrayList<>();
		managed.forEach((Node node) ->
		{
			itemHeight.add(computeChildPrefAreaHeight(node, Insets.EMPTY, -1));
		}
		);
		double itemHeightM = itemHeight.stream().max(Double::compare).orElse(12.0);

		// now build up columns
		final ArrayList<ArrayList<ArrayList<Node>>> cols = new ArrayList<>();
		double colLength = Math.floor(height / itemHeightM * 2.0);
		ArrayList<ArrayList<Node>> col = new ArrayList<>();
		col.add(new ArrayList<>());
		col.add(new ArrayList<>());
		boolean onLeft = true;
		int length = 0;

		for (Node node : managed)
		{
			if (onLeft)
			{
				if (getExpand(node))
				{
					if (length + 3 >= colLength)
					{
						// are we the last item? if so, bump to next row
						cols.add(col);
						col = new ArrayList<>();
						col.add(new ArrayList<>());
						col.add(new ArrayList<>());
						length = 0;
					}
					length += 1;
					onLeft = false;
					col.get(1).add(null);
				}
				length += 1;
				col.get(0).add(node);
			}
			else
			{
				length += 1;
				if (getExpand(node))
				{
					System.out.println("Warning: Unbalanced tree in TitledFormPane");
					length += 2;
					onLeft = false;
					col.get(1).add(null);
					col.get(1).add(null);
					col.get(0).add(node);
				}
				else
				{
					col.get(1).add(node);
				}
			}
			if (length + 1 >= colLength && !onLeft)
			{
				cols.add(col);
				col = new ArrayList<>();
				col.add(new ArrayList<>());
				col.add(new ArrayList<>());
				length = 0;
			}
			onLeft ^= true;
		}
		if (col.get(0).size() > 0)
		{
			cols.add(col);
		}

		int numCols = 2 * cols.size();
		ArrayList<Double> widths = new ArrayList<>();
		// computes ths widths of the columns
		for (ArrayList<ArrayList<Node>> pair : cols)
		{
			onLeft = true;
			for (ArrayList<Node> tmp : pair)
			{
				ArrayList<Double> wmax = new ArrayList<>();
				wmax.add(0.0);
				for (Node node : tmp)
				{
					if (node != null)
					{
						wmax.add(computeChildPrefAreaWidth(node, Insets.EMPTY, -1));
					}
				}
				double maxr = getMaxRightWidth();// || Double.MAX_VALUE;
				if (onLeft || maxr < 1)
				{
					maxr = Double.MAX_VALUE;
				}
				widths.add(Math.min(maxr, wmax.stream().max(Double::compare).get()));
				onLeft = false;
			}
		}
		//now we can set stuff
		int j = 0;
		double prefixX = left;
		for (ArrayList<ArrayList<Node>> pair : cols)
		{
			int i = 0;
			for (ArrayList<Node> tmp : pair)
			{
				double prefixY = top;
				double wmax = widths.get(j);
				for (Node node : tmp)
				{
					if (actualLayout && node != null)
					{
						//TODO: check bounds?
						layoutInArea(node, prefixX, prefixY,
									 getExpand(node) ? wmax + widths.get(j + 1) : wmax, itemHeightM, itemHeightM, Insets.EMPTY,
									 defaultHPos(i, node), VPos.CENTER);
					}
					//node.resizeRelocate(prefixX, prefixY, wmax, itemHeight)
					prefixY += itemHeightM;
				}
				prefixX += wmax + (getHgap());
				j += 1;
				i += 1;
			}
		}
		if (cols.size() > 1)
		{
			prefixX -= (getHgap());
		}
		this.lastWidth = prefixX + right;
	}

	private HPos defaultHPos(int i, Node node)
	{
		HPos eResult = GridPane.getHalignment(node) == null ? HPos.LEFT : GridPane.getHalignment(node);
		if (i == 0)
		{
			return getExpand(node) ? eResult : HPos.RIGHT;
		}
		else
		{
			return eResult;
		}

	}

	@Override
	public Orientation getContentBias()
	{
		return Orientation.VERTICAL;
	}

	// manually copied from JFX sources since they are package private stupidly
	private double computeChildPrefAreaWidth(Node child, Insets margin, double height)
	{

		double top = margin != null ? snapSpace(margin.getTop()) : 0;
		double bottom = margin != null ? snapSpace(margin.getBottom()) : 0;
		double left = margin != null ? snapSpace(margin.getLeft()) : 0;
		double right = margin != null ? snapSpace(margin.getRight()) : 0;
		double alt = -1;
		if (child.getContentBias() == Orientation.VERTICAL)
		{
			//# width depends on height
			alt = snapSize(boundedSize(height != -1 ? height - top - bottom
									   : child.prefHeight(-1), child.minHeight(-1), child.maxHeight(-1)));
		}
		double tmp = left + snapSize(boundedSize(child.prefWidth(alt), child.minWidth(alt), child.maxWidth(alt))) + right;
		return tmp;
	}

	private double computeChildPrefAreaHeight(Node child, Insets margin, double width)
	{

		double top = margin != null ? snapSpace(margin.getTop()) : 0;
		double bottom = margin != null ? snapSpace(margin.getBottom()) : 0;
		double left = margin != null ? snapSpace(margin.getLeft()) : 0;
		double right = margin != null ? snapSpace(margin.getRight()) : 0;
		double alt = -1;
		if (child.getContentBias() == Orientation.HORIZONTAL)
		{
			// width depends on height
			alt = snapSize(boundedSize(width != -1 ? width - left - right
									   : child.prefWidth(-1), child.minWidth(-1), child.maxWidth(-1)));
		}
		return top + snapSize(boundedSize(child.prefHeight(alt), child.minHeight(alt), child.maxHeight(alt))) + bottom;
	}

	private double boundedSize(double value, double min, double max)
	{
		return Math.min(Math.max(value, min), Math.max(min, max));
	}

	static private void setConstraint(Node paramNode, Object paramObject1, Object paramObject2)
	{
		if (paramObject2 == null)
		{
			paramNode.getProperties().remove(paramObject1);
		}
		else

		{
			paramNode.getProperties().put(paramObject1, paramObject2);
		}

		if (paramNode.getParent() != null)
		{
			paramNode.getParent().requestLayout();
		}

	}

	static Object getConstraint(Node paramNode, Object paramObject)
	{
		if (paramNode.hasProperties())
		{
			return paramNode.getProperties().get(paramObject);
		}
		return null;
	}
}
