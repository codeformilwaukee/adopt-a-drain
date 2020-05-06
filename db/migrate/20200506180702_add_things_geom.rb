class AddThingsGeom < ActiveRecord::Migration[6.0]
  def up
    execute """
    ALTER TABLE things ADD COLUMN geom_point geometry(Point,4326) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(lng::numeric, lat::numeric), 4326)) STORED;
    """

    add_index "things", "geography(geom_point)", name: "index_things_on_geography_geom_point_gist", using: :gist
  end

  def down
    remove_index :things, name: "index_things_on_geography_geom_point_gist"
    remove_column :things, :geom_point
  end
end
