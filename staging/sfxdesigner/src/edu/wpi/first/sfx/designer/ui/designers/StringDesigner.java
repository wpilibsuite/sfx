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
package edu.wpi.first.sfx.designer.ui.designers;

import edu.wpi.first.sfx.designer.util.Designers;
import edu.wpi.first.sfx.designer.util.Property;
import javafx.scene.Node;
import javafx.scene.control.TextField;

/**
 *
 * @author patrick
 */
public class StringDesigner implements Designers.Designer
{
	private TextField ui = new TextField();

	@Override
	public void design(Property type)
	{
		ui.textProperty().bindBidirectional(type.getProperty());
	}

	@Override
	public Node getUi()
	{
		return ui;
	}
	
}
