require 'open-uri'
require 'json'
require 'fileutils'

module GithubCommit
  def self.run
    owner = 'ChenZhangg'
    repo = 'autofix'
    token = 'b620abf700397a284c350966acdfa1406e00e5e5'
    #url = "https://api.github.com/repos/#{owner}/#{repo}/commits/#{sha}"
    url = "https://api.github.com/repos/#{owner}/#{repo}/commits?page=1"
    r = open(url, 'Authorization' => "token #{token}")
    remaining = r.meta['x-ratelimit-remaining'].to_i
    reset = r.meta['x-ratelimit-reset'].to_i
    contents = JSON.parse(r.read)
    p contents.class
    File.open('output.txt', 'w') do |f|
      f.puts JSON.pretty_generate(contents)
    end
  end
end
GithubCommit.run