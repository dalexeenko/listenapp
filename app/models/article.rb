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

include ActionView::Helpers::TextHelper

class Article < ActiveRecord::Base
  attr_accessible :article_url, :author, :body, :image_url, :preview, :preview_chunks, :source_id, :title
  has_many :chunks

  MAX_CHUNK_SIZE = 300

  def self.split_into_sub_sentences string
    sub_sentences = split_into_tokens string, '[\.\,:; ]'
    
    sub_sentences.inject([]){|b,j|
      if !b.last || (b.last.length + j.length > MAX_CHUNK_SIZE) then
        b << j
      else
        b.last << " #{j}"
      end
      b
    }
  end

  def self.split_into_chunks body
    sentences = split_into_tokens body, '[\.\?!]'

    sentences.inject([]){|a,i|
      if !a.last || (a.last.length + i.length > MAX_CHUNK_SIZE) then
        if i.length < MAX_CHUNK_SIZE
          a << i
        else
          sub_sentences = split_into_sub_sentences i

          sub_sentences.each do |part|
            a << part
          end
        end
      else
        a.last << " #{i}"
      end
      a
    }
  end

  def self.split_into_tokens(string, separator)
    string.scan(/(.+?#{separator}) ?/).map(&:first)
  end

  def self.update_from_feed(feed_url)
    feed = Feedzirra::Feed.fetch_and_parse(feed_url)
    feed.entries.each do |entry|
      unless exists? :article_url => entry.entry_id
        create!(
          :source_id => 13,
          :author => entry.author,
          :title => entry.title.strip,
          :image_url => (Nokogiri(entry.summary)/"img").at_css("img")['src'],
          :preview =>  truncate(ActionView::Base.full_sanitizer.sanitize(entry.summary.strip), :length => 500, :separator => ' '),
          :article_url => entry.entry_id,
          :body => ActionView::Base.full_sanitizer.sanitize(entry.content.strip)
        )
      end
    end
  end

  def self.populate_articles
    articles = Article.find :all,
                            :limit => 3,
                            :order => 'created_at desc',
                            :conditions => "preview_chunks IS NULL"

    articles.each do |article|
      title = article.title
      title_url = self.generate_audio(title)

      Chunk.create!(:article_id => article.id, :audio_url => title_url, :body => title)

      preview = split_into_chunks article.preview

      number_of_preview_chunks = 0

      preview.each do |preview_chunk|
        url = self.generate_audio(preview_chunk)
        Chunk.create!(:article_id => article.id, :audio_url => url, :body => preview_chunk)
        number_of_preview_chunks += 1
      end

      body = split_into_chunks article.body

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
      print file.url
    end

    file.url
  end

  def self.convert_tempfile(tempfile)
    dst = Tempfile.new(".mp3")

    cmd_args = [File.expand_path(tempfile.path), File.expand_path(dst.path)]
    system("bin/lame", *cmd_args)

    dst.binmode
    dst.path
  end
end
