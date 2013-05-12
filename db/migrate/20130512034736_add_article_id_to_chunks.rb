class AddArticleIdToChunks < ActiveRecord::Migration
  def change
    add_column :chunks, :article_id, :integer
  end
end
