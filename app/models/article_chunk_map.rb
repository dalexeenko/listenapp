# == Schema Information
#
# Table name: article_chunk_maps
#
#  id         :integer          not null, primary key
#  article_id :integer
#  chunk_id   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ArticleChunkMap < ActiveRecord::Base
  attr_accessible :article_id, :chunk_id
end
