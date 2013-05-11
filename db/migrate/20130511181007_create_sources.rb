class CreateSources < ActiveRecord::Migration
  def change
    create_table :sources do |t|
      t.string :name
      t.string :image_url
      t.string :favicon_url
      t.string :description
      t.string :rss_url
      t.string :source_url

      t.timestamps
    end
  end
end
