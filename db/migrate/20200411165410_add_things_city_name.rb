class AddThingsCityName < ActiveRecord::Migration[5.2]
  def change
    remove_index :things, :city_id
    add_column :things, :city_name, :text, null: false
    add_index :things, [:city_id, :city_name], unique: true
  end
end
