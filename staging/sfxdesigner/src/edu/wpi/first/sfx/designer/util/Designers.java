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
package edu.wpi.first.sfx.designer.util;

import edu.wpi.first.sfx.designer.ui.designers.StringDesigner;
import java.lang.reflect.InvocationTargetException;
import java.util.HashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import javafx.scene.Node;
import javafx.scene.control.Label;

/**
 *
 * @author patrick
 */
public class Designers
{

	private static HashMap<Class, Class<? extends Designer>> designerTypes = new HashMap<>();

	static
	{
		designerFor(StringDesigner.class, String.class);
	}

	public static void designerFor(Class<? extends Designer> dzn, Class... types)
	{
		for (Class clz : types)
		{
			designerTypes.put(clz, dzn); // TODO: worry about multiple ones
		}
	}

	public static Designer getFor(Class type)
	{
		Class<? extends Designer> dznrClz = designerTypes.get(type);
		// TODO: type is an enum
		if (dznrClz == null)
		{
			return new UnknownDesigner(type);
		}
		try
		{
			// TODO: lok at designers.rb and add error and enum handing
			return dznrClz.getConstructor().newInstance();
		}
		catch (NoSuchMethodException | SecurityException | InstantiationException | IllegalAccessException | IllegalArgumentException | InvocationTargetException ex)
		{
			return null;
		}
	}

	private static class UnknownDesigner implements Designer
	{

		Label ui;

		private UnknownDesigner(Class type)
		{
			ui = new Label("Unknown [" + type.getCanonicalName() + "]");
		}

		@Override
		public void design(Property type)
		{

		}

		@Override
		public Node getUi()
		{
			return ui;
		}

	}

	public static interface Designer
	{

		void design(Property type);

		Node getUi();
	}
}
