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
package edu.wpi.first.sfx.designer.rt;

import dashfx.lib.controls.Control;
import dashfx.lib.data.SmartValueTypes;
import java.io.InputStream;
import java.io.Serializable;

/**
 *
 * @author patrick
 */
public class JavaControlMI extends BaseMI implements Serializable
{

	private final Class<Control> jClass;
	private final String imageSource;

	public JavaControlMI(String name, String description, String category, String group, SmartValueTypes[] types, boolean saveChildren, boolean sealed, String[] propNames, Class<Control> c, String imageSource)
	{
		super(name, description, category, group, types, saveChildren, sealed, propNames);
		this.jClass = c;
		this.imageSource = imageSource;
	}

	@Override
	public InputStream getImageStream()
	{
		if (imageSource != null)
		{
			return jClass.getResourceAsStream(imageSource);
		}
		return null;
	}

	@Override
	public Control buildNew()
	{
		try
		{
			return jClass.newInstance();
		}
		catch (InstantiationException | IllegalAccessException ex)
		{
			throw new RuntimeException(ex);
		}
	}
}
