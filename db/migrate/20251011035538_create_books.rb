class CreateBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :books do |t|
      t.string :title
      t.string :author
      t.integer :status, null: false, default: 0
      t.text :note

      t.timestamps
    end
  end
end
