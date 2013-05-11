# == Schema Information
#
# Table name: sources
#
#  id          :integer          not null, primary key
#  name        :string(255)
#  image_url   :string(255)
#  favicon_url :string(255)
#  description :string(255)
#  rss_url     :string(255)
#  source_url  :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

require 'spec_helper'

describe Source do
  pending "add some examples to (or delete) #{__FILE__}"
end
