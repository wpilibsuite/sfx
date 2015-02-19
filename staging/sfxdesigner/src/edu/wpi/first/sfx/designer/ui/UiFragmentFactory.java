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

import javafx.scene.Node;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.TitledPane;
import javafx.scene.layout.FlowPane;

/**
 *
 * @author patrick
 */
public final class UiFragmentFactory
{
	private UiFragmentFactory(){}
	
	public static Pair<TitledPane,FlowPane> toolboxAccordionPane(String key)
	{
		FlowPane flow_pane = new FlowPane();
		flow_pane.setPrefWidth(200);
		flow_pane.setPrefHeight(200);
		
		ScrollPane sp = new ScrollPane(flow_pane);
		sp.setFitToWidth(true);
		sp.setMaxHeight(Double.POSITIVE_INFINITY);
		sp.setMaxWidth(Double.POSITIVE_INFINITY);
		sp.setHbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
		sp.setPannable(false);
		sp.setPrefHeight(-1);
		sp.setPrefViewportWidth(0);
		sp.setPrefWidth(-1);
		sp.getStyleClass().add("toolbox-panes");
		TitledPane tp = new TitledPane("Toolbox - " + (key == null ? "Ungrouped" : key), sp);
		return new Pair<>(tp, flow_pane);
	}
	
	public static class Pair<A,B>
	{
		public final A first;
		public final B second;

		public Pair(A first, B second)
		{
			this.first = first;
			this.second = second;
		}
		
	}
}
