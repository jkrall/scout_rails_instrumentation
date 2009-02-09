previous_verbosity = ActiveRecord::Migration.verbose
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define(:version => 0) do
  
  create_table :members, :force => true do |t|
    t.string :name
  end
  
end
ActiveRecord::Migration.verbose = previous_verbosity
