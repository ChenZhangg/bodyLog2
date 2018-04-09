require 'travis'
require 'open-uri'
require 'json'
require 'csv'
require 'fileutils'
require 'uri'
require 'find'
require 'open_uri_redirections'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'

def downloadJob(job_id,parent_dir)
  url="https://api.travis-ci.org/job/#{job_id}"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the job at #{url}: #{$!}"
    retry
  end
  file_name=File.join(parent_dir, "#{j['number'].gsub(/\./,'@')}.log")
  p file_name
  return if File.exist?(file_name) && File.size(file_name)>150
  job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job_id}/log.txt"
  p job_log_url
  count=0
  begin
    if job_log_url.include?('amazonaws')
      open(job_log_url) do |f|
        File.open(file_name,'w') do |file|
          file.puts(f.read)
        end
      end
    else
      open(job_log_url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ','Accept'=> 'text/plain',:allow_redirections => :all) do |f|
        File.open(file_name,'w') do |file|
          file.puts(f.read)
        end
      end
    end
  rescue => e
    error_message = "Retrying, fail to download job log #{job_log_url}: #{e.message}"
    job_log_url="http://api.travis-ci.org/job/#{job_id}/log" # if e.message.include?('403')
    puts error_message
    sleep 5
    count+=1
    retry if count<2
  end
end

def getJobs(build_id,parent_dir)
  url="https://api.travis-ci.org/build/#{build_id}"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the build at #{url}: #{$!}"
    retry
  end
  jobs=j['jobs']
  jobs.each do |job|
    downloadJob(job['id'],parent_dir)
  end
end

def get_build_id(repo_id, build_number, offset, largest_build_number)
  offset=largest_build_number-build_number unless offset
  url="https://api.travis-ci.org/repo/#{repo_id}/builds?limit=25&offset=#{offset}"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the repo builds  at #{url}: #{$!}"
    retry
  end
  builds=j['builds']
  build_id=nil
  builds.each do |build|
    if build['number'].to_i == build_number
      build_id=build['id']
      break
    end
  end

  next_offset=j['@pagination']['next']?j['@pagination']['next']['offset']:nil

  if build_id.nil?
    build_id=get_build_id(repo_id, build_number, next_offset, largest_build_number) if next_offset
    puts "Failed to find the build #{build_number}" unless next_offset
  else
    puts "Successed to find the build #{build_number} at #{url}"
  end

  build_id
end

def errorFile(parent_dir,largest_build_number)
  s1=(1..largest_build_number).to_a.to_set
  s2=Set.new
  Find.find(parent_dir) do |f|
    if File.file?(f) && /\/([\d]+)@[\d]+\.log/=~f && File.size(f)>150
      s2<< $1.to_i
    end
  end
  s=s1-s2
end

def get_last_build_number(repo_id)
  url= "https://api.travis-ci.org/repo/#{repo_id}/builds"
  begin
    f = open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j = JSON.parse f.read
  rescue
    puts "Failed to get the largest build number at #{url}: #{$!}"
    retry
  end
  last_build_number = j['builds'][0]['number'].to_i
end

def get_repo_id(repo_name)
  puts "Scanning repo #{repo_name}"
  parent_dir = File.join('..', 'build_logs', repo_name.gsub(/\//,'@'))
  FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
  repo_slug=repo_name.sub(/\//,'%2F')

  count=0
  begin
    f=open("https://api.travis-ci.org/repo/#{repo_slug}",'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the repo id of #{repo_name}: #{$!}"
    sleep 5
    count += 1
    retry if count < 10
    return
  end
  repo_id = j['id']
  last_build_number = get_last_build_number(repo_id)

  #s = errorFile(parent_dir, last_build_number)
  s = (1..largest_build_number).to_a
  threads = []
  s.each do |build_number|
    thr=Thread.new(build_number) do |build_number|
      build_id=get_build_id(repo_id, build_number, nil, last_build_number)
      getJobs(build_id,parent_dir) if build_id
    end
    threads<<thr
    loop do
      count=Thread.list.count{|thread| thread.alive? }
      break if count <= 10
    end
  end
  threads.each do |thr|
    thr.join if thr.alive?
  end
end

def scan_csv(csv_path)
  flag = true
  CSV.foreach(csv_path, headers: false) do |row|
    flag = false  if row[0].include?('checkstyle')
    next if flag
    get_repo_id("#{row[0]}") #if row[2].to_i>=1000
  end
end

def scan_mysql(id,builds,stars)
  TravisJavaRepository.where("id > ? AND builds > ? AND stars>?", id, builds, stars).find_each do |e|
    p e.repo_name
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
scan_mysql(1, 5000, 1000)
#scan_csv('Above1000WithTravisAbove1000.csv')
#puts open('http://s3.amazonaws.com/archive.travis-ci.org/jobs/37569269/log.txt').read