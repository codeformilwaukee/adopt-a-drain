# frozen_string_literal: true

class AddDebrisRemovedPoundsToThings < ActiveRecord::Migration[5.2]
  def change
    add_column :things, :debris_removed_pounds, :integer, default: 0, null: false
  end
end
