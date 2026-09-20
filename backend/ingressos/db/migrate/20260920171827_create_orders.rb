class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status, default: 0
      t.decimal :total, precision: 10, scale: 2

      t.timestamps
    end
  end
end
