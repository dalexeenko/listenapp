class CreateChunks < ActiveRecord::Migration
  def change
    create_table :chunks do |t|
      t.string :audio_url
      t.text :body

      t.timestamps
    end
  end
end
