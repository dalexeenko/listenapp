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

require 'spec_helper'

describe Chunk do
  pending "add some examples to (or delete) #{__FILE__}"
end
