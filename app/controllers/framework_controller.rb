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
  
  def show_columns
    render :json => columns
  end
  
  def create_column
    model = params[:model].camelize
    name = params[:column_name].camelize
    `rails generate migration Add#{name}To#{model} #{name}:#{params[:column_type]}`
    `rake db:migrate`
      
    render :json => columns.last
  end
  
  def remove_column
    `rails generate migration Remove#{params[:column]}From#{params[:model]} #{params[:column]}:#{params[:column_type]}`
    `rake db:migrate`
    `rm db/migrate/*remove_#{params[:column].camelize}_from_#{params[:model]}.rb`
    `rm db/migrate/*add_#{params[:column]}_to_#{params[:model]}.rb`
    
    render :status => :ok, :text => "#{params[:column]} removed from #{params[:model]}"
  end
  
  def show_associations
    render :json => associations(params[:model])
  end

  def create_association
    model = params[:model].camelize.singularize
    target = params[:association_target].camelize.singularize
    
    # add the appropriate column to the database, create a line
    
    case params[:association_type]
    when 'many'
      `rails generate migration Add#{model.pluralize}To#{target.pluralize} #{model}_id:integer`
    when 'one'
      `rails generate migration Add#{model.singularize}To#{target.pluralize} #{model}_id:integer`
    when 'belongs'
      `rails generate migration Add#{target.singularize}To#{model.pluralize} #{target.singularize}_id:integer`
    end
    
    # migrate the database
    `rake db:migrate`
    
    # adjust the model file to include the association
    class_line = 0
    lines = File.read("app/models/#{model}.rb").split("\n")
    lines.each_with_index do |line, i|
      if line.match(/^class #{model.camelize}/) then
        class_line = i
        break
      end
    end
    lines.insert(class_line+1, association_line(params[:association_type], target))
    File.open("app/models/#{model}.rb", 'w') {|f| f.write(lines.join("\n")) }
          
    render :status => :ok, :text => "association created successfully"
  end
  
  def remove_association
    model = params[:model].singularize
    target = params[:association_target].camelize.singularize
    
    # add the appropriate column to the database, create a line 
    association_line = ""
    case params[:association_type]
    when 'many'
      `rails generate migration Remove#{model.pluralize}From#{target.pluralize} #{model}_id:integer`
    when 'one'
      `rails generate migration Remove#{model.singularize}From#{target.pluralize} #{target.singularize}`
    when 'belongs'
      `rails generate migration Remove#{target.singularize}From#{model.pluralize} #{target}`
    end
    
    # migrate the database
    `rake db:migrate`
    
    # TODO: remove both add and remove migrations
    
    # remove the lines from the model files
    lines = File.read("app/models/#{model}.rb").split("\n")
    lines.delete_if do |line|
      line.contains(association_line(params[:association_type], params[:association_target])) 
    end
    File.open("app/models/#{model}.rb", 'w') {|f| f.write(lines.join("\n")) }
    
    render :status => :ok, :text => "association removed"
  end
  
  private
  
  # sneaky stuff that powers the introspection..
  # .. could have used ActiveRecord::Base.descendants if the models were autoloaded
  def models
    Dir['app/models/*.rb'].map {|f| File.basename(f, '.*').camelize.pluralize }
  end
  
  def columns
    params[:model].singularize.camelize.constantize.columns.delete_if {|x| x.name == "id" || x.name.match(".*_id$")}
  end
  
  def associations(model)
    # TODO: I'm sure this could be done in one line by someone more skillful and less tired
    vals = []
    model.singularize.camelize.constantize.reflections.each do |key,value|
      if value.instance_of?(ActiveRecord::Reflection::AssociationReflection) then
        vals << {"type" => value.macro.to_s, "target" => value.name.to_s}
      end
    end
    vals
  end
  
  def next_migration_prefix
    DateTime.now.to_s(:number)
    # TODO: figure out how to make this conditional on the migration numbering config 
    # ie. config.active_record.timestamped_migrations = false
    # "%03d" % (Dir["db/migrate/*.rb"].sort.map { |f| File.basename(f) }.last.to_i + 1).to_s
  end
  
  def association_line(type, target)
    case type
    when 'many'
      association_line = "\thas_many :#{target.pluralize}"
    when 'one'
      association_line = "\thas_one :#{target.singularize}"
    when 'belongs'
      association_line = "\tbelongs_to :#{target.singularize}"
    end
  end
  
end