require "rubygems"
require "pp"

items = []

File.open('sample.txt').each do |line|
	print line
	items << line
end

# Determine encoding format, (1) csv (2) name-value (3) json (4) yaml (5) xml (6) text
# If text determined then do the following
# Try to extract parameters from the current line 
# In the following order: timestamp, url, path, ip with and without port, mac-address, float, long
# Once matched parameters are extracted, mask them using grok patterns
# Add the result to specimens collection, then create a graph of levinstein distance between the collection members 
# Perform k-means over EM clustering algorithm on the graph
# Try to match "parameters" in each cluster
# *** RESULTS ***





items.each do |line2|
	pp line2
end

pp items[2]

exit


grok = Grok.new

# Load some default patterns that ship with grok.
# See also: 
#   http://code.google.com/p/semicomplete/source/browse/grok/patterns/base
grok.add_patterns_from_file("patterns/pure-ruby/base")

# Using the patterns we know, try to build a grok pattern that best matches 
# a string we give. Let's try Time.now.to_s, which has this format;
# => Fri Apr 16 19:15:27 -0700 2010
input = "http://www.google.com/ and 00:de:ad:be:ef:00 with 'Something Nice'"
pattern = grok.discover(input)

#g = Grok.new
#g.add_patterns_from_file("patterns/pure-ruby/base")
#g.compile("%{MAC}")
#p g.match("00:de:ad:be:ef:00").captures

puts "Input: #{input}"
puts "Pattern: #{pattern}"
