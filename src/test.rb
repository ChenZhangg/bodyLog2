require 'open-uri'
require 'json'
url = "https://api.travis-ci.org/job/38171"
#f = open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
#j= JSON.parse f.read
#p j
#puts JSON.pretty_generate(j)
regexp = /"number": "([.\d]+)"/
p regexp =~ ' "435.1"'
p $1