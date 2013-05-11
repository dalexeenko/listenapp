class CreateUserDeviceMaps < ActiveRecord::Migration
  def change
    create_table :user_device_maps do |t|
      t.integer :user_id
      t.integer :device_id

      t.timestamps
    end
  end
end
