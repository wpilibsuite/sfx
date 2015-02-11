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

import dashfx.lib.data.SmartValueTypes;
import dashfx.lib.rt.ControlMetaInfo;

/**
 *
 * @author patrick
 */
public abstract class BaseMI implements ControlMetaInfo
{

	private final String name;
	private final String description;
	private final String category;
	private final String group;
	private final SmartValueTypes[] types;
	private final boolean saveChildren;
	private final boolean sealed;
	private final String[] propNames;

	protected BaseMI(String name, String description, String category, String group, SmartValueTypes[] types, boolean saveChildren, boolean sealed, String[] propNames)
	{
		this.name = name;
		this.description = description;
		this.category = category;
		this.group = group;
		this.types = types;
		this.saveChildren = saveChildren;
		this.sealed = sealed;
		this.propNames = propNames;
	}

	@Override
	public String getName()
	{
		return name;
	}

	@Override
	public String getDescription()
	{
		return description;
	}

	@Override
	public String getCategory()
	{
		return category;
	}

	@Override
	public String getGroup()
	{
		return group;
	}

	@Override
	public SmartValueTypes[] getTypes()
	{
		return types;
	}

	@Override
	public boolean isSaveChildren()
	{
		return saveChildren;
	}

	@Override
	public boolean isSealed()
	{
		return sealed;
	}

	@Override
	public String[] getLocalPropertyNames()
	{
		return propNames;
	}

	@Override
	public String __getVersion_do_NOT_implement_4355a46b19d348dc2f57c046f8ef63d4538ebb936000f3c9ee954a27460dd865()
	{
		return "1.0";
	}
}
