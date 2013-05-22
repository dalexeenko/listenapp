desc "Fetch TechChrunch articles via RSS and save new ones to the database."
task :update_feed => :environment do
  puts "Fetching articles..."
  Article.update_from_feed('http://feeds.feedburner.com/TechCrunch/')
  Article.populate_articles
  puts "Done."
end
