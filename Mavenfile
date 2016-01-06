Version = "2015.11.01"

group_id "edu.wpi.first.wpilib"
artifact_id "sfx"
version Version
packaging "pom"

# oddly, bundler is not installed by maven jruby tools by default, so we manualy specify it here
gem "bundler", "~>1.7.6"
gemfile # require all gems and jars
jarfile

properties('tesla.dump.pom' => 'pom.xml', 'tesla.dump.readOnly' => true, "DO_NOT_MODIFY_POM_XML_ITS_FROM_Mavenfile._USE_POLYGLOT_to_Generate_it" => "then just run mvn package to make the new pom")

profile "default-repo" do
	activation do
		activeByDefault true
		property :name => "!repo"
	end
	repository :id => "Local Repo", :url => "file://${user.home}/releases/maven/development"
	repository :id => "FRC Binaries", :url => "http://first.wpi.edu/FRC/c/maven/development"

end
profile "custom-repo" do
	activation do
		activeByDefault true
		property :name => "repo"
	end
	repository :id => "Local Repo", :url => "file://${user.home}/releases/maven/${repo}"
	repository :id => "FRC Binaries", :url => "http://first.wpi.edu/FRC/c/maven/${repo}"

end


# rake tasks
plugin('de.saumya.mojo:rake-maven-plugin') do
	self.execute_goals(:rake, phase: :compile, id: 'rakemvnfile')
end

plugin("org.codehaus.mojo:build-helper-maven-plugin", "1.9.1") do
	execute_goals("attach-artifact", phase: :package, id: "attach-artifacts", artifacts: {artifact: {file: "target/sfx-#{Version}-zip.zip", type: :zip}})
end

plugin "dependency" do
	execute_goals("copy-dependencies", phase: "process-sources")
end

plugin "org.apache.maven.plugins:maven-assembly-plugin" do
	execute_goals("single", id: "create-distro", phase: :package, descriptors: {descriptor: "zip.xml"})
end

distribution_management do
	repository :id => "FRC Local", :url => 'file://${user.home}/releases/maven/${repo}'
end
