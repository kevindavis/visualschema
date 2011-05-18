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
    type = params[:association_type]
    
    # add the appropriate columns to the database, add lines to the models
    add_association_to_model(type, model, target)
    case type
    when 'has_many'
      `rails generate migration Add#{model.pluralize}To#{target.pluralize} #{model.downcase}_id:integer`
      add_association_to_model("belongs_to", target, model)
    when 'has_one'
      `rails generate migration Add#{model.singularize}To#{target.pluralize} #{model.downcase}_id:integer`
      add_association_to_model("belongs_to", target, model)
    # going to approach all adding from the source 
    # when 'belongs_to'
    #   `rails generate migration Add#{target.singularize}To#{model.pluralize} #{target.downcase.singularize}_id:integer`
    #   add_association_to_model("has_one", target) // don't know it's just one.. could be many
    end
    
    # migrate the database
    `rake db:migrate`
    
    # adjust the model file to include the association
          
    render :status => :ok, :text => "association created successfully"
  end
  
  def remove_association
    model = params[:model].singularize
    target = params[:association_target].camelize.singularize
    type = params[:association_type]
    
    # remove the appropriate column from the database, remove the lines from the model
    remove_association_from_model(type, model, target)
    post_migration_commands = []
    case type
    when 'has_many'
      `rails generate migration Remove#{model.pluralize}From#{target.pluralize} #{model}_id:integer`
      remove_association_from_model("belongs_to", target, model)
      post_migration_commands << "rm db/migrate/*add_#{model.pluralize}_to_#{target.pluralize}.rb"
    when 'has_one'
      `rails generate migration Remove#{model.singularize}From#{target.pluralize} #{target.singularize}`
      remove_association_from_model("belongs_to", target, model)
      post_migration_commands << "rm db/migrate/*add_#{model.singularize}_to_#{target.pluralize}.rb"
    # going to drive all the modifications of the associations from the source
    # when 'belongs_to'
    #   `rails generate migration Remove#{target.singularize}From#{model.pluralize} #{target}`
    end
        
    `rake db:migrate`
    post_migration_commands.each { |command| `#{command}` }
    
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
    when 'has_many'
      association_line = "\thas_many :#{target.downcase.pluralize}"
    when 'has_one'
      association_line = "\thas_one :#{target.downcase.singularize}"
    when 'belongs_to'
      association_line = "\tbelongs_to :#{target.downcase.singularize}"
    end
  end
  
  def add_association_to_model(type, model, target)
    class_line = 0
    lines = File.read("app/models/#{model}.rb").split("\n")
    lines.each_with_index do |line, i|
      if line.match(/^class #{model.camelize}/) then
        class_line = i
        break
      end
    end
    lines.insert(class_line+1, association_line(type, target))
    File.open("app/models/#{model}.rb", 'w') {|f| f.write(lines.join("\n")) }
  end
  
  def remove_association_from_model(type, model, target)
    lines = File.read("app/models/#{model}.rb").split("\n")
    debugger
    lines.delete_if do |line|
      debugger
      line.include? association_line(type, target)
    end
    File.open("app/models/#{model}.rb", 'w') {|f| f.write(lines.join("\n")) }
  end
  
end