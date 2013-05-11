class CreateDevices < ActiveRecord::Migration
  def change
    create_table :devices do |t|
      t.string :device_guid

      t.timestamps
    end
  end
end
