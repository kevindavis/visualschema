rm app/models/*.rb
rm db/migrate/*
rm test/unit/*_test.rb
rm test/fixtures/*
rm db/schema.rb

rake db:drop
