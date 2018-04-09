require 'csv'
require 'open-uri'
require 'json'
require 'fileutils'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'


def get_job_json(job_id, parent_dir)
  url = "https://api.travis-ci.org/job/#{job_id}"
  begin
    f = open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the job at #{url}: #{$!}"
    sleep 20
    retry
  end

  file_name = File.join(parent_dir, "job@#{j['number'].sub(/\./,'@')}.json")

  unless File.exist?(file_name) && File.size?(file_name)!=nil
    File.open(file_name, 'w') do |file|
      file.puts(JSON.pretty_generate(j))
    end
  end
  puts "#Download from #{url} to #{file_name}"
end

def get_build_json(build_id, parent_dir)
  url = "https://api.travis-ci.org/build/#{build_id}"
  begin
    f = open(url, 'Travis-API-Version' => '3', 'Authorization' => 'token C-cYiDyx1DUXq3rjwWXmoQ')
    j = JSON.parse f.read
  rescue
    puts "Failed to get the build at #{url}: #{$!}"
    sleep 20
    retry
  end
  #puts JSON.pretty_generate(j)

  file_name = File.join(parent_dir, "build@#{j['number']}.json")

  unless File.exist?(file_name) && File.size?(file_name)!=nil
    File.open(file_name,'w') do |file|
      file.puts(JSON.pretty_generate(j))
    end
  end

  puts "#Download from #{url} to #{file_name}"

  jobs = j['jobs']
  jobs.each do |job|
    get_job_json(job['id'], parent_dir)
  end

end

def get_builds_list(repo_id, offset, parent_dir)
  threads = []
  while offset
    url = "https://api.travis-ci.org/repo/#{repo_id}/builds?limit=25&offset=#{offset}"
    begin
      f = open(url, 'Travis-API-Version'=>'3', 'Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
      j = JSON.parse f.read
    rescue
      puts "Failed to get the repo builds list at #{url}: #{$!}"
      sleep 20
      retry
    end
    #puts JSON.pretty_generate(j)
    offset = j['@pagination']['next'] ? j['@pagination']['next']['offset'] : nil
    builds = j['builds']

    builds.each do |build|
      thr = Thread.new(build['id']) do |build_id|
        get_build_json(build_id, parent_dir)
      end
      threads << thr
      loop do
        count = Thread.list.count{ |thread| thread.alive? }
        break if count <= 200
      end
    end
    threads.delete_if{|thread| !thread.alive?}
  end
  threads.each do |thr|
    thr.join if thr.alive?
  end
end

def get_repo_id(repo_name, parent_dir)
  repo_slug = repo_name.sub(/\//,'%2F')
  count=0
  begin
    f = open("https://api.travis-ci.org/repo/#{repo_slug}",'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j = JSON.parse f.read
  rescue
    puts "Failed to get the repo id of #{repo_name}: #{$!}"
    sleep 20
    count += 1
    retry if count<10
    return
  end
  id = j['id']
  get_builds_list(id, 0, parent_dir)
  #puts JSON.pretty_generate(j)
end

def scan_csv(file)
  flag = true
  CSV.foreach(file) do |row|
    repo_name = row[0]
    flag=false  if repo_name.include?('tananaev')
    next if flag
    parent_dir = File.join('..', 'json_files', repo_name.gsub(/\//,'@'))
    FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
    get_repo_id(repo_name, parent_dir)
  end
end

def scan_mysql(id, builds, stars)
  TravisJavaRepository.where("id >= ? AND builds > ? AND stars>?", id, builds, stars).find_each do |e|
    puts "Scan project #{e.repo_name}   id=#{e.id}   builds=#{e.builds}   stars=#{e.stars}"
    repo_name = e.repo_name
    parent_dir = File.join('..', 'json_files', repo_name.gsub(/\//,'@'))
    FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
    get_repo_id(repo_name, parent_dir)
  end
end

class TravisJavaRepository < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.131.252.160",
      username: "root",
      password: "root",
      database: "zc"
  )
end

Thread.abort_on_exception = true
scan_mysql(1, 50, 0)
#scanProjectsInCsv('Above1000WithTravisAbove1000.csv')
