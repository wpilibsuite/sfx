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

import java.lang.reflect.Method;

/**
 *
 * @author patrick
 */
public class Property
{
	private String camel;
	private String name;
	private String description;
	private String category;
	private Object object;
	private Method method;

	public Property(String value, String description)
	{
		name = value;
		this.description = description;
		category = "General";
	}

	public Property(String value, String description, String category)
	{
		name = value;
		this.description = description;
		this.category = category;
	}

	/**
	 * @return the camel
	 */
	public String getCamel()
	{
		return camel;
	}

	/**
	 * @param camel the camel to set
	 */
	public void setCamel(String camel)
	{
		this.camel = camel;
	}

	/**
	 * @return the name
	 */
	public String getName()
	{
		return name;
	}

	/**
	 * @param name the name to set
	 */
	public void setName(String name)
	{
		this.name = name;
	}

	/**
	 * @return the description
	 */
	public String getDescription()
	{
		return description;
	}

	/**
	 * @param description the description to set
	 */
	public void setDescription(String description)
	{
		this.description = description;
	}

	/**
	 * @return the category
	 */
	public String getCategory()
	{
		return category;
	}

	/**
	 * @param category the category to set
	 */
	public void setCategory(String category)
	{
		this.category = category;
	}

	/**
	 * @return the object
	 */
	public Object getObject()
	{
		return object;
	}

	/**
	 * @param object the object to set
	 */
	public void setObject(Object object)
	{
		this.object = object;
	}

	/**
	 * @return the method
	 */
	public Method getMethod()
	{
		return method;
	}

	/**
	 * @param method the method to set
	 */
	public void setMethod(Method method)
	{
		this.method = method;
	}
}
