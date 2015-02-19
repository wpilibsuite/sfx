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

import edu.wpi.first.sfx.designer.ui.DesignerUI;
import dashfx.lib.rt.ControlMetaInfo;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.function.Consumer;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import org.jruby.embed.ScriptingContainer;

/**
 *
 * @author patrick
 */
public final class DepManager
{

	private static final DepManager instance = new DepManager();

	private final Map<String, CompletableFuture> futures = new HashMap<>();
	private final Map<String, Consumer<CompletableFuture>> runnables = new HashMap<>();
	private ScriptingContainer jRuby;
	private DesignerUI ui;
	private final ObservableList<ControlMetaInfo> toolbox_controls = FXCollections.observableArrayList();

	private DepManager()
	{
		futures.put("build_ui", new CompletableFuture());
		futures.get("build_ui").thenAccept(ui -> {
			this.ui = (DesignerUI) ui;
			
		});

		on("base_jruby_loaded", x -> { // Initial JRuby loading takes like 5 or so seconds , everything else is super fast
			jRuby = new ScriptingContainer();
			jRuby.runScriptlet("mi = Java::edu.wpi.first.sfx.designer.DepManager.instance; $LOAD_PATH << mi.lp; require 'adapter.rb'; Adapter.new(mi)");
		});
		futures.get("base_jruby_loaded").thenAccept(x -> launch("load_jruby_plugins"));
	}

	public ObservableList<ControlMetaInfo> getToolboxControls()
	{
		return toolbox_controls;
	}

	public ScriptingContainer getJRuby()
	{
		return jRuby;
	}
	
	/*
	 * This is somewhat of a kludge to avoid defining interfaces. We should really consider
	 * using a interface or cleaning up its usage when finished with the port
	 */
	public static <T> T scriptCall(Object receiver, String methodName, Class<T> returnType)
	{
		return instance.jRuby.callMethod(receiver, methodName, returnType);
	}
	
	/*
	 * This is somewhat of a kludge to avoid defining interfaces. We should really consider
	 * using a interface or cleaning up its usage when finished with the port
	 */
	public static Object scriptEval(Object arg, String eval)
	{
		instance.jRuby.put("x", arg);
		Object r = instance.jRuby.runScriptlet(eval);
		instance.jRuby.remove("x");
		return r;
	}
	public static DepManager getInstance()
	{
		return instance;
	}

	public DesignerUI getUi()
	{
		return ui;
	}

	/**
	 * Returns the local load path for ruby
	 *
	 * @return
	 */
	public String getLp()
	{
		return "/home/patrick/NetBeansProjects/sfx/lib";
	}

	public void complete(String depStages, Object o)
	{
		futures.get(depStages).complete(o);
	}

	public void abort(String depStages, Throwable t)
	{
		futures.get(depStages).completeExceptionally(t);
	}

	public void on(String depStages, Consumer<CompletableFuture> r)
	{
		if (futures.containsKey(depStages))
		{
			throw new RuntimeException("Can not overwrite keys in the dep manager, a future already existed for " + depStages);
		}
		futures.put(depStages, new CompletableFuture());
		runnables.put(depStages, r);
	}

	public void launch(String depStages)
	{
		runnables.get(depStages).accept(futures.get(depStages));
	}
}
