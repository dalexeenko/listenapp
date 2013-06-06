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
require 'htmlentities'
require 'stanford-core-nlp'
require 'addressable/uri'

include ActionView::Helpers::TextHelper

class Article < ActiveRecord::Base
  attr_accessible :article_url, :author, :body, :image_url, :preview, :preview_chunks, :source_id, :title
  has_many :chunks

  MAX_CHUNK_SIZE = 300

  def self.split_into_sentences text
    #StanfordCoreNLP.jar_path = '/app/bin/stanford-core-nlp/'
    #StanfordCoreNLP.model_path = '/app/bin/stanford-core-nlp/'

    pipeline = StanfordCoreNLP.load(:tokenize, :ssplit)
    text = StanfordCoreNLP::Annotation.new(text)
    pipeline.annotate(text)
    text.get(:sentences).to_a.map &:to_s
  end

  def self.split_into_chunks text
    sentences = split_into_sentences text
    sentences = sentences.map {|sentence| sentence.length > MAX_CHUNK_SIZE ? word_wrap(sentence, :line_width => MAX_CHUNK_SIZE).split("\n") : sentence }.flatten

    sentences.reduce([]){|a,i|
      if !a.last || (a.last.length + i.length > MAX_CHUNK_SIZE) then
          a << i
      else
        a.last << " #{i}"
      end
      a
    }
  end

  def self.update_from_feed(feed_url)
    feed = Feedzirra::Feed.fetch_and_parse(feed_url)
    feed.entries.each do |entry|
      unless exists? :article_url => entry.entry_id
        image_url = Addressable::URI.parse((Nokogiri(entry.summary)/"img").at_css("img")['src'])
        params = image_url.query_values
        params.delete('crop')
        params['w'] = (params['w'].to_i * 2).to_s
        params['h'] = (params['h'].to_i * 2).to_s
        image_url.query_values = params

        create!(
          :source_id => 13,
          :author => entry.author,
          :title => entry.title.strip,
          :image_url => image_url.to_s,
          :preview => HTMLEntities.new.decode(truncate(ActionView::Base.full_sanitizer.strip_tags(entry.summary.strip), :length => 500, :separator => ' ')),
          :article_url => entry.entry_id,
          :body => HTMLEntities.new.decode(ActionView::Base.full_sanitizer.strip_tags(entry.content.strip))
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
