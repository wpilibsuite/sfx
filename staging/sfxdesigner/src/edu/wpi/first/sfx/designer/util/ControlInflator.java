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

import dashfx.lib.controls.Control;
import dashfx.lib.rt.ControlMetaInfo;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import javafx.scene.Node;

/**
 *
 * @author patrick
 */
public interface ControlInflator
{
	CompletableFuture<Control> inflate(ControlMetaInfo type, Map<String, Object> properties);

	public void setProperty(String key, Object valueAdded, Node center);
	public void resetProperty(String key, Node center);
}
