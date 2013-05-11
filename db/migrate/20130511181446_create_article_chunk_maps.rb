class CreateArticleChunkMaps < ActiveRecord::Migration
  def change
    create_table :article_chunk_maps do |t|
      t.integer :article_id
      t.integer :chunk_id

      t.timestamps
    end
  end
end
