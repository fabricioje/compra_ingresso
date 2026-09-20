class CreateSeats < ActiveRecord::Migration[8.1]
  def change
    create_table :seats do |t|
      t.references :event, null: false, foreign_key: true
      t.string :sector
      t.string :row
      t.string :number
      t.decimal :price, precision: 10, scale: 2
      t.integer :status, default: 0
      t.datetime :reserved_until
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
