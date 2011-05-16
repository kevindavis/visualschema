class FrameworkController < ApplicationController

  # routing through this method to use form helpers..  
  def framework
  end

  # returns the models in the app
  def show_models
    render :json => models
  end
  
  def create_model
    # TODO: be more clever about this - maybe use git ?
    model = params[:model].singularize
    
    # generate a model and migrate the database
    `rails generate model #{model} name:string`
    `rake db:migrate`
    
    render :status => :ok, :text => model
  end
  
  def remove_model
    model = params[:model].downcase
    model_plural = model.pluralize

    # generate a migration file and run it
    migration = 
    "class Drop#{model_plural.camelize} < ActiveRecord::Migration
      def self.up
        drop_table :#{model_plural}
      end
    end"
    File.open("db/migrate/#{next_migration_prefix}_drop_#{model_plural}.rb", "w") {|f| f.write(migration)}
    `rake db:migrate`
    
    # remove the generated files
    # TODO: be more clever about this - remove only if they haven't been touched? use git and rollback?
    `rm app/models/#{model}.rb`
    `rm test/unit/#{model}_test.rb`
    `rm test/fixtures/#{model_plural}.yml`
    
    # remove both the create and drop migrations (avoiding a problem if we try to re-add a model)
    `rm db/migrate/*create_#{model_plural}.rb`
    `rm db/migrate/*drop_#{model_plural}.rb`    
    
    redirect_to '/'
  end
  
  # returns the columns for a given model
  def show_columns
    render :json => columns
  end
  
  # adds a given column, of a given type to a model
  def create_column
    model = params[:model].camelize
    name = params[:column_name].camelize
    `rails generate migration Add#{name}To#{model} #{name}:#{params[:column_type]}`
    `rake db:migrate`
      
    render :json => columns.last
  end
  
  # removes a given column from a given model
  def remove_column
    `rails generate migration Remove#{params[:column]}From#{params[:model]}`
    `rake db:migrate`
    `rm db/migrate/*Remove#{params[:column]}From#{params[:model]}.rb`
    `rm db/migrate/Add#{params[:column]}To#{params[:model]}.rb`
    
    render :status => :ok, :text => "#{params[:column]} removed from #{params[:model]}"
  end
  
  def show_associations
    render :json => associations
  end


  private
  
  # sneaky stuff that powers the introspection..
  # .. could have used ActiveRecord::Base.descendants if the models were autoloaded
  def models
    Dir['app/models/*.rb'].map {|f| File.basename(f, '.*').camelize }
  end
  
  def columns
    params[:model].camelize.constantize.columns.delete_if {|x| x.name == "id" || x.name.match(".*_id$")}
  end
  
  def associations
    params[:model].camelize.constantize.reflections.each { |key, value| association_names << key if value.instance_of?(ActiveRecord::Reflection::AssociationReflection) }
  end
  
  def next_migration_prefix
    DateTime.now.to_s(:number)
    # TODO: figure out how to make this conditional on the migration numbering config 
    # ie. config.active_record.timestamped_migrations = false
    # "%03d" % (Dir["db/migrate/*.rb"].sort.map { |f| File.basename(f) }.last.to_i + 1).to_s
  end

end



