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

class Source < ActiveRecord::Base
  # attr_accessible :description, :favicon_url, :image_url, :name, :rss_url, :source_url
end
