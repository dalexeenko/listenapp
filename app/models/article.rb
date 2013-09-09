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

require 'addressable/uri'
require 'htmlentities'
require "net/http"
require "net/https"
require 'open-uri'
require 's3'
require 'stanford-core-nlp'
require "uri"

include ActionView::Helpers::TextHelper

class Article < ActiveRecord::Base
  attr_accessible :article_url
  attr_accessible :author
  attr_accessible :body
  attr_accessible :image_url
  attr_accessible :preview
  attr_accessible :preview_chunks
  attr_accessible :published_at
  attr_accessible :source_id
  attr_accessible :title

  has_many :chunks

  # Max number of characters in a single chunk
  MAX_CHUNK_SIZE = 300

  # Max number of characters in an article summary
  SUMMARY_SIZE = 800

  # Splits given piece of text into array with sentences
  #
  def self.split_into_sentences text
    StanfordCoreNLP.jar_path = '/app/bin/stanford-core-nlp/'
    StanfordCoreNLP.model_path = '/app/bin/stanford-core-nlp/'

    pipeline = StanfordCoreNLP.load(:tokenize, :ssplit)
    text = StanfordCoreNLP::Annotation.new(text)
    pipeline.annotate(text)
    text.get(:sentences).to_a.map &:to_s
  end

  # Splits given piece of text into chunks
  #
  def self.split_into_chunks text
    sentences = split_into_sentences text

    sentences = sentences.map { |sentence|
      sentence.length > MAX_CHUNK_SIZE ?
        word_wrap(sentence, :line_width => MAX_CHUNK_SIZE).split("\n") :
        sentence
    }.flatten

    sentences.reduce([]){ |a, i|
      if !a.last || (a.last.length + i.length > MAX_CHUNK_SIZE) then
          a << i
      else
        a.last << " #{i}"
      end
      a
    }
  end

  # Extracts summary from an article
  #
  def self.extract_summary text
    sentences = split_into_sentences text

    sentences.reduce([]){|a,i|
      if !a.last || (a.last.length + i.length > SUMMARY_SIZE) then
          a << i
      else
        a.last << " #{i}"
      end
      a
    }
  end

  # Fetches articles from RSS feed and saves them into the database
  #
  def self.update_from_feed(feed_url)
    feed = Feedzirra::Feed.fetch_and_parse(feed_url)

    feed.entries.sort_by! { |e| e.published }

    feed.entries.each do |entry|
      unless exists? :article_url => entry.entry_id

        source = Source.all :conditions => { :rss_url => feed_url }

        if (!(Nokogiri(entry.summary)/"img").at_css("img").nil?) &&
          (source.first.name.include? "TechCrunch") then
          image_url = Addressable::URI.parse(
            (Nokogiri(entry.summary)/"img").at_css("img")['src'])

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
            image_url = "https://talkieapp.s3.amazonaws.com/ars-logo.jpg"
          elsif source.first.name.include? "The Verge" then
            image_url = "https://talkieapp.s3.amazonaws.com/theverge-logo.jpg"
          elsif source.first.name.include? "The New York Times" then
            image_url = "https://talkieapp.s3.amazonaws.com/nyt-logo.jpg"
          elsif source.first.name.include? "Washington Post" then
            image_url = "https://talkieapp.s3.amazonaws.com/wp-logo.jpg"
          elsif source.first.name.include? "The Guardian" then
            image_url = "https://talkieapp.s3.amazonaws.com/guardian-logo.jpg"
          elsif source.first.name.include? "E! Online" then
            image_url = "https://talkieapp.s3.amazonaws.com/eonline-logo.jpg"
          elsif source.first.name.include? "Huffpost" then
            image_url = "https://talkieapp.s3.amazonaws.com/huffington-logo.jpg"
          elsif source.first.name.include? "Yahoo" then
            image_url = "https://talkieapp.s3.amazonaws.com/yahoo-logo.jpg"
          end
        end

        if source.first.name.include? "The Guardian" then
          image_url = "https://talkieapp.s3.amazonaws.com/guardian-logo.jpg"
        end

        if entry.content.nil? then
          content = entry.summary
        else
          content = entry.content
        end

        content = HTMLEntities.new.decode(
          ActionView::Base.full_sanitizer.strip_tags(content).squish)

        sentences = extract_summary content
        summary = sentences[0]

        # Skip the article if there is no article content (body)
        next if content.nil? || content.length == 0

        content.slice! summary
        content.strip!

        if source.first.name.include? "Washington Post" then
          summary.slice! "Read full article \u003E\u003E"
        end

        create!(
          :source_id => source.first.id,
          :author => entry.author.to_s.truncate(250, separator: ' '),
          :title => entry.title.strip.to_s.truncate(250, separator: ' '),
          :image_url => image_url.to_s.truncate(250, separator: ' '),
          :preview => summary,
          :published_at => entry.published,
          :article_url => entry.entry_id,
          :body => content
        )
      end
    end
  end

  # Fetches articles from RSS feeds and generates audio chunks for them
  #
  def self.populate_articles
    articles = Article.find(
      :all,
      :order => 'id desc',
      :conditions => "preview_chunks IS NULL")

    articles.each do |article|
      begin
        title = article.title
        title_url = self.generate_audio_bing(title, "voice")
        Chunk.create!(
          :article_id => article.id,
          :audio_url => title_url,
          :body => title)

        preview = split_into_chunks article.preview
        number_of_preview_chunks = 0

        preview.each do |preview_chunk|
          url = self.generate_audio_bing(preview_chunk, "voice")
          Chunk.create!(
            :article_id => article.id,
            :audio_url => url,
            :body => preview_chunk)
          number_of_preview_chunks += 1
        end

        body = split_into_chunks article.body

        body.each do |body_chunk|
          url = self.generate_audio_bing(body_chunk, "voice")
          Chunk.create!(
            :article_id => article.id,
            :audio_url => url,
            :body => body_chunk)
        end

        article.preview_chunks = number_of_preview_chunks
        article.save
      rescue ArgumentError
        puts "Something went wrong!"
        article.preview_chunks = -1
        article.save
      end
    end
  end

  # AT&T text-to-speech
  def self.generate_audio(text, voice)
    uri = URI.parse("http://192.20.225.36/tts/cgi-bin/nph-nvdemo")

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({"voice" => voice, "txt" => text})
    response = http.request(request)
    redirectLocation = response['location']

    raise ArgumentError, "redirect location is nil! request: " + request.to_s +
      "; text: " + text if redirectLocation.nil?

    amazon = S3::Service.new(
      access_key_id: 'AKIAJMGKXIP5RHBHSMMA',
      secret_access_key: '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')
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

  # Loquendo/Nuance text-to-speech
  def self.generate_audio_nuance(text, voice)
    puts "Voice used = " + voice
    uri = URI.parse("https://tts.nuancemobility.net:443/NMDPTTSCmdServlet/tts")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri.request_uri)

    request.set_form_data(
      {
        "codec" => "wav",
        voice => voice,
        "ttsLang" => "en_US",
        "text" => text,
        "appId" => "NMDPTRIAL_dmitry_alexeenko20130627022038",
        "appKey" => "79711b1aad792b84364c85d3f633551286d6645570b657959c272dd0c6449e3fb5b959623384e769d06c3cc69f91d925673d7bd7f3d26d8ffa9a60c0defe0093",
        "id" => "0000"})

    request = Net::HTTP::Get.new(uri.request_uri + '?' + request.body)

    response = http.request(request)

    raise ArgumentError, "Exceeded max number of transactions per day." if response.code == "503"

    amazon = S3::Service.new(
      access_key_id: 'AKIAJMGKXIP5RHBHSMMA', 
      secret_access_key: '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')
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

  # Bing text-to-speech
  def self.generate_audio_bing(text, voice)
    clientID = "listenapp"
    clientSecret = "Q7fSU9UNs1lNbEtxzMcozmAp/hB6vocQoGoxwpOlGJg="
    authUrl = "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13/"
    scopeUrl = "http://api.microsofttranslator.com"
    grantType = "client_credentials"

    uri = URI.parse(authUrl)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data(
      {
        "client_id" => clientID,
        "client_secret" => clientSecret,
        "grant_type" => grantType,
        "scope" => scopeUrl
      })

    response = http.request(request)

    access_token = JSON.parse(response.body)["access_token"]

    uri = URI.parse("http://api.microsofttranslator.com/V2/Http.svc/Speak")
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Get.new(uri.request_uri)

    request.set_form_data(
      {
        "text" => text,
        "language" => "en",
        "format" => "audio/mp3",
        "options" => "minsize"
      })

    request = Net::HTTP::Get.new(uri.request_uri + '?' + request.body)
    request["Authorization"] = "Bearer " + access_token

    response = http.request(request)

    amazon = S3::Service.new(
      access_key_id: 'AKIAJMGKXIP5RHBHSMMA',
      secret_access_key: '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')
    bucket = amazon.buckets.find('talkieapp')

    open("tempfile_bing.mp3", "wb") do |file|
        file.write(response.body)
    end    

    wavfile = Tempfile.new(".mp3")
    wavfile.binmode

    open("tempfile_bing.mp3", "rb") do |file|
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

    # Converting mp3 to mp3 with smallest file size and reasonable quality.
    # See http://macintoshhowto.com/audio/how-to-compress-speech.html for
    # more info regarding lame parameters
    cmd_args = [
      "--mp3input",
      "--abr", # average bitrate
      "8", # kbps
      "-q",
      "0", # best quality available at this bitrate
      "-m",
      "m", # mono
      File.expand_path(tempfile.path),
      File.expand_path(dst.path)]

    system("bin/lame", *cmd_args)

    dst.binmode
    dst.path
  end
end
