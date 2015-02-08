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

import java.util.concurrent.ForkJoinPool;
import javafx.application.Application;
import static javafx.application.Application.launch;
import javafx.fxml.FXMLLoader;
import javafx.scene.Parent;
import javafx.scene.Scene;
import javafx.scene.image.Image;
import javafx.stage.Stage;
import org.jruby.embed.ScriptingContainer;

/**
 *
 * @author patrick
 */
public class Main extends Application
{
	
	static Main instance;

	@Override
	public void init() throws Exception
	{
		super.init();
		instance = this;
		ForkJoinPool.commonPool().execute(() -> DepManager.getInstance().launch("base_jruby_loaded"));
	}

	public static Main getInstance()
	{
		return instance;
	}
	

	@Override
	public void start(Stage stage) throws Exception
	{
		Parent root = FXMLLoader.load(Main.class.getResource("res/SFX.fxml"));
		Scene scene = new Scene(root);
		stage.setTitle("SmartDashboard");
		stage.getIcons().add(new Image(Main.class.getResourceAsStream("res/img/16-fxicon.png")));
		stage.getIcons().add(new Image(Main.class.getResourceAsStream("res/img/32-fxicon.png")));
		stage.getIcons().add(new Image(Main.class.getResourceAsStream("res/img/60-fxicon.png")));
		stage.setScene(scene);
		stage.show();
	}

	/**
	 * @param args the command line arguments
	 */
	public static void main(String[] args)
	{
		//System.out.println("You are launching this wrong... Please use JavaFX tools. Method will be removed in future versions.");
		launch(args);
	}
}