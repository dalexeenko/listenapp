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
require "net/https"
require "uri"
require 'open-uri'
require 's3'
require 'htmlentities'
require 'stanford-core-nlp'
require 'addressable/uri'

include ActionView::Helpers::TextHelper

class Article < ActiveRecord::Base
  attr_accessible :article_url, :author, :body, :image_url, :preview, :preview_chunks, :source_id, :title, :published_at
  has_many :chunks

  MAX_CHUNK_SIZE = 300

  SUMMARY_SIZE = 800

  def self.split_into_sentences text
    StanfordCoreNLP.jar_path = '/app/bin/stanford-core-nlp/'
    StanfordCoreNLP.model_path = '/app/bin/stanford-core-nlp/'

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

  def self.generate_summary content
    sentences = split_into_sentences content

    sentences.reduce([]){|a,i|
      if !a.last || (a.last.length + i.length > SUMMARY_SIZE) then
          a << i
      else
        a.last << " #{i}"
      end
      a
    }
  end

  def self.update_from_feed(feed_url)
    feed = Feedzirra::Feed.fetch_and_parse(feed_url)

    feed.entries.sort_by! { |e| e.published }

    feed.entries.each do |entry|
      unless exists? :article_url => entry.entry_id

        source = Source.all :conditions => { :rss_url => feed_url }

        if !(Nokogiri(entry.summary)/"img").at_css("img").nil? then
          image_url = Addressable::URI.parse((Nokogiri(entry.summary)/"img").at_css("img")['src'])
          params = image_url.query_values
          params.delete('crop')
          params['w'] = (params['w'].to_i * 2).to_s
          params['h'] = (params['h'].to_i * 2).to_s
          image_url.query_values = params
        else
          if source.first.name.include? "TechCrunch" then
            image_url = "https://talkieapp.s3.amazonaws.com/techcrunch-logo.jpg"
          elsif source.first.name.include? "CNN" then
            image_url = "https://talkieapp.s3.amazonaws.com/cnn-logo.jpg"
          elsif source.first.name.include? "Ars Technica" then
            image_url = "https://talkieapp.s3.amazonaws.com/cnn-logo.jpg"
          end
        end

        if entry.content.nil? then
          c = entry.summary
        else
          c = entry.content
        end

        content = HTMLEntities.new.decode(ActionView::Base.full_sanitizer.strip_tags(c).squish)
        sentences = generate_summary content
        summary = sentences[0]

        next if content.nil? || content.length == 0

        content.slice! summary
        content.strip!

        puts "Title: " + entry.title.strip + "\n"
        puts "Summary: " + summary + "\n"

        create!(
          :source_id => source.first.id,
          :author => entry.author,
          :title => entry.title.strip,
          :image_url => image_url.to_s,
          :preview => summary,
          :published_at => entry.published,
          :article_url => entry.entry_id,
          :body => content
        )
      end
    end
  end

  def self.populate_articles
    articles = Article.find :all,
                            :order => 'id desc',
                            :conditions => "preview_chunks IS NULL",
                            :limit => 10

    articles.each do |article|
      begin

        r = rand(5)

        if r == 0 then
          voice = 'crystal'
        elsif r == 1 then
          voice = 'mike'
        elsif r == 2 then
          voice = 'rich'
        elsif r == 3 then
          voice = 'lauren'
        elsif r == 4 then
          voice = 'claire'
        end

        title = article.title
        title_url = self.generate_audio_nuance(title, voice)

        Chunk.create!(:article_id => article.id, :audio_url => title_url, :body => title)

        preview = split_into_chunks article.preview

        number_of_preview_chunks = 0

        preview.each do |preview_chunk|
          url = self.generate_audio_nuance(preview_chunk, voice)
          Chunk.create!(:article_id => article.id, :audio_url => url, :body => preview_chunk)
          number_of_preview_chunks += 1
        end

        body = split_into_chunks article.body

        body.each do |body_chunk|
          url = self.generate_audio_nuance(body_chunk, voice)
          Chunk.create!(:article_id => article.id, :audio_url => url, :body => body_chunk)
        end

        article.preview_chunks = number_of_preview_chunks
        article.save
      rescue ArgumentError
        puts "Exception!"
        article.preview_chunks = -1
        article.save
      end
    end
  end

  def self.generate_audio(text, voice)
    uri = URI.parse("http://192.20.225.36/tts/cgi-bin/nph-nvdemo")

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({"voice" => voice, "txt" => text})
    response = http.request(request)
    redirectLocation = response['location']

    # $ curl -v -H "Accept:text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q-H "Content-Type:application/x-www-form-urlencoded"
    # -X POST -d 'voice=crystal&txt=Access+Notifications+On+The+Lock+Screen+A+minor+but+ongoing+frustration+with+iOS’s+earlier+
    # implementation+of+the+Notification+Center+is+that+it+required+you+to+unlock+your+device.&speakButton=SPEAK' http://192.20.225.36/tts/cgi-bin/nph-nvdemo
    #This interactive text-to-speech site is provided by AT&T solely
    # for demonstration purposes.  Any distribution, professional, or commercial use is
    # strictly disallowed. 
    raise ArgumentError, "redirect location is nil! request: " + request.to_s + "; text: " + text if redirectLocation.nil?

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

  def self.generate_audio_nuance(text, voice)
    uri = URI.parse("https://tts.nuancemobility.net:443/NMDPTTSCmdServlet/tts")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri.request_uri)

    request.set_form_data({"codec" => "wav", "ttsLang" => "en_US", "text" => text, "appId" => "NMDPTRIAL_dmitry_alexeenko20130627022038", "appKey" => "79711b1aad792b84364c85d3f633551286d6645570b657959c272dd0c6449e3fb5b959623384e769d06c3cc69f91d925673d7bd7f3d26d8ffa9a60c0defe0093", "id" => "0000"})

    request = Net::HTTP::Get.new(uri.request_uri + '?' + request.body)

    response = http.request(request)

    raise ArgumentError, "Exceeded maximum number of transactions per day." if response.code == "503"

    amazon = S3::Service.new(access_key_id: 'AKIAJMGKXIP5RHBHSMMA', secret_access_key: '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')
    bucket = amazon.buckets.find('talkieapp')

    open("tempfile_nuance.wav", "wb") do |file|
        file.write(response.body)
    end    

    wavfile = Tempfile.new(".wav")
    wavfile.binmode

    open("tempfile_nuance.wav", "rb") do |file|
      wavfile << file.read
    end

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
