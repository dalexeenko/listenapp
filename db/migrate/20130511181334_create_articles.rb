class CreateArticles < ActiveRecord::Migration
  def change
    create_table :articles do |t|
      t.integer :source_id
      t.string :author
      t.string :title
      t.string :preview
      t.string :image_url
      t.string :article_url
      t.text :body
      t.integer :preview_chunks

      t.timestamps
    end
  end
end
