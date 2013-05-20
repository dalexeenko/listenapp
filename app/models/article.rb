# == Schema Information
#
# Table name: articles
#
#  id             :integer          not null, primary key
#  source_id      :integer
#  author         :string(255)
#  title          :string(255)
#  preview        :string(255)
#  image_url      :string(255)
#  article_url    :string(255)
#  body           :text
#  preview_chunks :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

class Article < ActiveRecord::Base
  attr_accessible :article_url, :author, :body, :image_url, :preview, :preview_chunks, :source_id, :title
  has_many :chunks

  def self.update_from_feed(feed_url)
  	feed_url = "http://feeds.feedburner.com/TechCrunch/"
  	feed = Feedzirra::Feed.fetch_and_parse(feed_url)
  	feed.entries.each do |entry|
  		unless exists? :article_url => entry.url
  			create!(
  				:title => entry.title,
  				:preview => entry.summary,
  				:article_url => entry.url,
  				:body => entry.content
  			)
  		end
  	end
  end
end
