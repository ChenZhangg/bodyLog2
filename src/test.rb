require 'open-uri'
require 'json'
require 'travis'
=begin
url = "https://api.travis-ci.org/user/724655"
f = open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
j= JSON.parse f.read
#p j
puts JSON.pretty_generate(j)
#https://api.github.com/users/lpereir4ruby
=end
trepo = Travis::Repository.find('rails/rails')
p trepo.id
p trepo.name
p trepo.slug
tbuild = trepo.build('1000')
p tbuild.jobs