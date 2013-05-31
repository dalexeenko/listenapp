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

require "net/http"
require "uri"
require 'open-uri'
require 's3'

class Article < ActiveRecord::Base
  attr_accessible :article_url, :author, :body, :image_url, :preview, :preview_chunks, :source_id, :title
  has_many :chunks

  def self.update_from_feed(feed_url)
  	feed = Feedzirra::Feed.fetch_and_parse(feed_url)
  	feed.entries.each do |entry|
  		unless exists? :article_url => entry.entry_id
  			create!(
  				:source_id => 13,
  				:author => entry.author,
  				:title => entry.title,
          :image_url => (Nokogiri(entry.summary)/"img").map{ |i| i['src'] },
  				:preview => ActionView::Base.full_sanitizer.sanitize(entry.summary),
  				:article_url => entry.entry_id,
  				:body => ActionView::Base.full_sanitizer.sanitize(entry.content)
  			)
  		end
  	end
  end

  def self.populate_articles
    articles = Article.find :all,
                            :limit => 3,
                            :order => 'created_at desc'

    articles.each do |article|
      title = article.title
      title_url = self.generate_audio(title)

      Chunk.create!(:article_id => article.id, :audio_url => title_url, :body => title)

      preview = article.preview.scan(/.{1,300}/m)

      number_of_preview_chunks = 0

      preview.each do |preview_chunk|
        url = self.generate_audio(preview_chunk)
        Chunk.create!(:article_id => article.id, :audio_url => url, :body => preview_chunk)
        number_of_preview_chunks += 1
      end

      body = article.body.scan(/.{1,300}/m)

      body.each do |body_chunk|
        url = self.generate_audio(body_chunk)
        Chunk.create!(:article_id => article.id, :audio_url => url, :body => body_chunk)
      end

      article.preview_chunks = number_of_preview_chunks
      article.save
    end
  end

  def self.generate_audio(text)
    uri = URI.parse("http://192.20.225.36/tts/cgi-bin/nph-nvdemo")

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({"voice" => "crystal", "txt" => text})
    response = http.request(request)
    redirectLocation = response['location']

    amazon = S3::Service.new(access_key_id: 'AKIAJMGKXIP5RHBHSMMA', secret_access_key: '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')
    bucket = amazon.buckets.find('talkieapp')
    url = 'http://192.20.225.36' + redirectLocation

    #open('temp.wav', 'wb') do |file|
    #  file << open(url).read
    #end

    wavfile = Tempfile.new(".wav")
    wavfile.binmode

    open(url) do |f|
      wavfile << f.read
    end

    wavfile.close

    mp3 = convert_tempfile(wavfile)

    file = bucket.objects.build(SecureRandom.uuid + '.mp3')
    file.content = (File.read mp3)

    if file.save
      # Make a new ActiveRecord::Base class for this
      #LogFile.create(size: download.size, type: download.type, name: url)
      print file.url
    end

    file.url
  end

  def self.convert_tempfile(tempfile)
    dst = Tempfile.new(".mp3")

    cmd_args = [File.expand_path(tempfile.path), File.expand_path(dst.path)]
    system("bin/lame", *cmd_args)

    dst.binmode
    #io = StringIO.new(dst.read)
    #dst.close

    #io.original_filename = "sound.mp3"
    #io.content_type = "audio/mpeg"

    #io
    dst.path
  end
end
