class CreateEvent < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :name
      t.string :local
      t.date :date
      t.time :time

      t.timestamps
    end
  end
end
