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

require 'spec_helper'

describe ArticleChunkMap do
  pending "add some examples to (or delete) #{__FILE__}"
end
