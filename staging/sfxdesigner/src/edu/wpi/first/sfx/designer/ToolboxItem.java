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
package edu.wpi.first.sfx.designer;

import java.io.IOException;
import java.io.InputStream;
import javafx.event.*;
import javafx.fxml.FXML;
import javafx.fxml.FXMLLoader;
import javafx.scene.control.Label;
import javafx.scene.control.Tooltip;
import javafx.scene.image.*;
import javafx.scene.input.MouseEvent;
import javafx.scene.layout.*;

/**
 *
 * @author patrick
 */
public class ToolboxItem extends VBox
{

	@FXML
	private ImageView img;

	@FXML
	private Label label;
	private final Object obj;

	@FXML
	void begin_drag(MouseEvent event)
	{
		//TODO: fill
	}

	public ToolboxItem(Object o)
	{
		this.obj = o;
		String mode = "";
		if (true) //FIXME: TODO: SD::DesignerSupport::Preferences.toolbox_icons
		{
			//mode = "OnlyText";
		}
		FXMLLoader fxmlLoader = new FXMLLoader(getClass().getResource("res/DesignerToolboxItem" + mode + ".fxml"));
		fxmlLoader.setRoot(this);
		fxmlLoader.setController(this);

		try
		{
			fxmlLoader.load();
		}
		catch (IOException exception)
		{
			throw new RuntimeException(exception);
		}
		
		if (label != null)
			label.setText(o.toString());
		
		Tooltip tt= new Tooltip();
		tt.setGraphic(new VBox(new Label(DepManager.scriptCall(obj, "name", String.class)), 
				new Label(DepManager.scriptCall(obj, "description", String.class))));
		Tooltip.install(this, tt);
		InputStream is = DepManager.scriptCall(obj, "image_stream", InputStream.class);
		if (is != null && img != null)
			img.setImage(new Image(is));
	}

}
