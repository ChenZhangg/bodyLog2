require 'travis'
require 'open-uri'
require 'json'
require 'csv'
require 'fileutils'
require 'uri'
require 'net/http'
require 'find'

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

  count=0
  begin
    if job_log_url.include?('amazonaws')
      open(job_log_url) do |f|
        File.open(file_name,'w') do |file|
          file.puts(f.read)
        end
      end
    else
      open(job_log_url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ') do |f|
        File.open(file_name,'w') do |file|
          file.puts(f.read)
        end
      end
    end
  rescue => e
    error_message = "Retrying, fail to download job log #{job_log_url}: #{e.message}"
    job_log_url="http://api.travis-ci.org/jobs/#{job_id}/log" if e.message.include?('403')
    puts error_message
    sleep 20
    count+=1
    retry if count<5
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

def getBuildId(repo_id,build_number,offset,largest_build_number)
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
    build_id=getBuildId(repo_id,build_number,next_offset,largest_build_number) if next_offset
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

def getLargestBuildNumber(repo_id)
  url="https://api.travis-ci.org/repo/#{repo_id}/builds"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the largest build number at #{url}: #{$!}"
    retry
  end
  largest_build_number=j['builds'][0]['number'].to_i
end

def getRepoId(repo_name)
  puts "Scanning repo #{repo_name}"
  parent_dir=File.join('..','build_logs',repo_name.gsub(/\//,'@'))
  FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
  repo_slug=repo_name.sub(/\//,'%2F')
  begin
    f=open("https://api.travis-ci.org/repo/#{repo_slug}",'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the repo id of #{repo_name}: #{$!}"
    retry
  end
  repo_id=j['id']
  largest_build_number=getLargestBuildNumber(repo_id)

  s=errorFile(parent_dir,largest_build_number)
  threads=[]
  s.each do |build_number|
    thr=Thread.new(build_number) do |build_number|
      build_id=getBuildId(repo_id,build_number,nil,largest_build_number)
      getJobs(build_id,parent_dir)
    end
    threads<<thr
    loop do
      count=Thread.list.count{|thread| thread.alive? }
      break if count <= 200
    end
  end
  threads.each do |thr|
    thr.join if thr.alive?
  end
end

def eachRepository(input_CSV)
  CSV.foreach(input_CSV,headers:false) do |row|
    getRepoId("#{row[0]}") #if row[2].to_i>=1000
  end
end

eachRepository('Above1000WithTravisAbove1000.csv')
