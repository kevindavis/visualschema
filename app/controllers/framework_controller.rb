class FrameworkController < ApplicationController

  # routing through this method to use form helpers..  
  def framework
  end

  # returns the models in the app
  def show_models
    render :json => models
  end
  
  def add_model
  end
  
  def remove_model
  end
  
  # returns the columns for a given model
  def columns
    render :json => params[:model].constantize.columns
  end
  
  # removes a given column from a given model
  def remove_column
    
  end
  
  # adds a given column, of a given type to a model
  def add_column
    
  end


  private
  
  # sneaky stuff that powers the introspection..
  # .. could have used ActiveRecord::Base.descendants if the models were autoloaded
  def models
    Dir['app/models/*.rb'].map {|f| File.basename(f, '.*').camelize }
  end
  
  def associations(model)
    model.reflections.each { |key, value| association_names << key if value.instance_of?(ActiveRecord::Reflection::AssociationReflection) }
  end
  
end



