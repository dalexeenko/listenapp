# == Schema Information
#
# Table name: chunks
#
#  id         :integer          not null, primary key
#  audio_url  :string(255)
#  body       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Chunk < ActiveRecord::Base
  attr_accessible :audio_url, :body
  belongs_to :article
end
