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

import edu.wpi.first.sfx.designer.ui.CTView;
import dashfx.controls.DataAnchorPane;
import dashfx.lib.rt.ControlMetaInfo;
import dashfx.lib.util.ControlTree;
import edu.wpi.first.sfx.designer.util.ControlInflator;
import edu.wpi.first.sfx.designer.util.DesignerLUT;
import java.net.URL;
import javafx.beans.property.SimpleObjectProperty;

/**
 *
 * @author patrick
 */
public final class DesignerMetadata
{

	private final DesignerLUT<CTView> viewlut = new DesignerLUT<>();
	private final ControlTree root;
	private final SimpleObjectProperty<ControlTree> editing = new SimpleObjectProperty<>();
	private final SimpleObjectProperty<ControlTree> selected = new SimpleObjectProperty<>();
	private final ControlInflator inflator;
	private final URL defaulturl;

	public DesignerMetadata(ControlMetaInfo rootClass, ControlInflator infl, URL url)
	{
		defaulturl = url;
		inflator = infl;
		root = new ControlTree(rootClass);
		CTView base = new CTView(url, root, this, true);
		viewlut.put(root, base);
		setEditing(root);
		base.init();
	}
	
	public CTView getAssociatedView(ControlTree tree)
	{
		if (tree == null)
			return null;
		CTView av = viewlut.get(tree);
		if (av == null)
		{
			av = new CTView(defaulturl, tree, this, false);
			viewlut.put(tree, av);
			av.init();
		}
		return av;
	}

	public ControlTree getRoot()
	{
		return root;
	}

	public final ControlTree getEditing()
	{
		return editing.get();
	}

	public final void setEditing(ControlTree ct)
	{
		editing.set(ct);
		selected.set(null);
	}

	public SimpleObjectProperty<ControlTree> editingProperty()
	{
		return editing;
	}

	public final ControlTree getSelected()
	{
		return selected.get();
	}

	public final void setSelected(ControlTree ct)
	{
		selected.set(ct);
	}

	public SimpleObjectProperty<ControlTree> selectedProperty()
	{
		return selected;
	}

	public ControlInflator getInflator()
	{
		return inflator;
	}

	public ControlTree newNode(ControlTree tree, ControlMetaInfo cname)
	{
		ControlTree lTree = new ControlTree(cname);
		tree.getChildren().add(lTree); // TODO: should this inflate the item here, or in the view with ObservableLIsts
		return lTree;
	}

}
