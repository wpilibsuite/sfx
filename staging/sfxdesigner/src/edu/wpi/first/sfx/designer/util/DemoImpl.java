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

import edu.wpi.first.sfx.designer.util.ControlInflator;
import dashfx.lib.controls.Control;
import dashfx.lib.rt.ControlMetaInfo;
import java.util.LinkedList;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import javafx.application.Platform;
import javafx.scene.Node;

/**
 *
 * @author patrick
 */
public class DemoImpl implements ControlInflator
{

	@Override
	public CompletableFuture<Control> inflate(ControlMetaInfo type, Map<String, Object> properties)
	{
		CompletableFuture<Control> f = new CompletableFuture<>();
		q.add(new j3(f, type, properties));
		// TODO: may not be threadsafe
		//s.interrupt();
		return f;
	}

	@Override
	public void setProperty(String key, Object valueAdded, Node center)
	{
		throw new UnsupportedOperationException("Not supported yet."); //To change body of generated methods, choose Tools | Templates.
	}

	@Override
	public void resetProperty(String key, Node center)
	{
		throw new UnsupportedOperationException("Not supported yet."); //To change body of generated methods, choose Tools | Templates.
	}

	public static class j3
	{

		public final Map<String, Object> properties;
		public final ControlMetaInfo type;
		public final CompletableFuture<Control> future;

		public j3(CompletableFuture<Control> future, ControlMetaInfo type, Map<String, Object> properties)
		{
			this.future = future;
			this.type = type;
			this.properties = properties;
		}
	}

	private LinkedList<j3> q = new LinkedList<>();

	private Thread s;
	private boolean running = true;

	public void runService()
	{
		s = new Thread(() ->
		{
			while (running)
			{
				while (q.isEmpty())
				{
					try
					{
						Thread.sleep(100);
					}
					catch (InterruptedException ex)
					{
						
					}
				}
				final j3 e = q.pop();
				Platform.runLater(() ->
				{
					try
					{
						Control b = e.type.buildNew();
						e.future.complete(b);
					}
					catch (Throwable ex)
					{
						ex.printStackTrace();
						e.future.completeExceptionally(ex);
					}
				});
			}
		});
		s.setDaemon(true);
		s.start();
	}
}
