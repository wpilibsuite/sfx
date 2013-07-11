#import javafx.scene.paint.Color;

module SD::Designers
  @@designer_types = {}

	def designer_for(*types)
    types.each do |type|
      type = type.java_class unless type.is_a? Java::JavaClass
      @@designer_types[type] = self
    end
  end

  def get_for(type)
    type = type.java_class unless type.is_a? Java::JavaClass
    #TODO: if not found, search entire classpath
    dznrClz = @@designer_types[type]
    if type.enum?
      dznrClz = @@designer_types[java.lang.Enum.java_class]
    end
    return nil unless dznrClz
    begin
      pd = dznrClz.ruby_class.new
      if (type.enum?)
        pd.enum = type
      end
      return pd
    rescue java.lang.Throwable
      return nil
    end
  end

  module_function :get_for
end