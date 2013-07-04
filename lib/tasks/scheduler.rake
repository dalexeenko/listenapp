desc "Fetch TechChrunch articles via RSS and save new ones to the database."
task :update_feed => :environment do
	#if (Time.now.hour % 4) == 0
		puts "Fetching articles..."
		Article.update_from_feed('http://feeds.feedburner.com/TechCrunch/')
		#Article.update_from_feed('http://rss.cnn.com/rss/cnn_topstories.rss')
		#Article.update_from_feed('http://feeds.arstechnica.com/arstechnica/index')
		Article.populate_articles
		puts "Done."
	#end

    require "net/http"
    
	http = Net::HTTP.new('talkieapp.herokuapp.com')
	http = http.start
	url = 'https://talkieapp.herokuapp.com/articles.json'
	req = Net::HTTP::Get.new(URI.encode(url))
	req.basic_auth 'dmitry@talkie.com', 'foobar'
	res = http.request(req)

	http = Net::HTTP.new('talkieapp-staging.herokuapp.com')
	http = http.start
	url = 'https://talkieapp-staging.herokuapp.com/articles.json'
	req = Net::HTTP::Get.new(URI.encode(url))
	req.basic_auth 'dmitry@talkie.com', 'foobar'
	res = http.request(req)

	http = Net::HTTP.new('talkieapp-signup.herokuapp.com')
	http = http.start
	url = 'https://talkieapp-signup.herokuapp.com/users.json'
	req = Net::HTTP::Get.new(URI.encode(url))
	res = http.request(req)

	Article.destroy_all(['updated_at < ?', 14.days.ago])
	Chunk.destroy_all(['updated_at < ?', 14.days.ago])
end
