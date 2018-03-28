require 'travis'
require 'open-uri'
require 'json'
require 'csv'
require 'fileutils'
require 'uri'
require 'net/http'
require 'find'

def downloadJob(job,job_number)
  name=File.join(@parent_dir, "#{job_number.gsub(/\./,'@')}.log")
  #job_log_url="http://api.travis-ci.org/jobs/#{job}/log"
  job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job}/log.txt"
  return if File.exist?(name)&&(File.size?(name)!=nil)
  puts name
  count=0
  begin
    open(job_log_url) do |f|
      File.open(name,'w') do |file|
        file.puts(f.read)
      end
    end
  rescue => e
    error_message = "Retrying, fail to download job log #{job_log_url}: #{e.message}"
    job_log_url="http://api.travis-ci.org/jobs/#{job}/log" if e.message.include?('403')
    puts error_message
    sleep 20
    count+=1
    retry if count<5
  end
end

def jobLogs(jobs)
  jobs.each do |job|
    url="https://api.travis-ci.org/jobs/#{job}"
    count=0
    begin
      resp=open(url,'Content-Type'=>'application/json','Accept'=>'application/vnd.travis-ci.2+json')
      job_json=JSON.parse(resp.read)
      downloadJob(job,job_json['job']['number'])
    rescue => e
      error_message = "Retrying, fail to download job log #{url}: #{e.message}"
      puts error_message
      sleep 20
      count+=1
      retry if count<5
    end
  end
end

def getBuild(build)
  jobLogs(build['job_ids'])
end

def paginateBuild(last_build_number,repo_id)
  count=0
  begin
    url="https://api.travis-ci.org/builds?after_number=#{last_build_number}&repository_id=#{repo_id}"
    resp=open(url,'Content-Type'=>'application/json','Accept'=>'application/vnd.travis-ci.2+json')
    builds=JSON.parse(resp.read)
    #puts JSON.pretty_generate(builds)
    builds['builds'].reverse_each do |build|
      getBuild(build)
    end
  rescue  Exception => e
    error_message = "Retrying, but Error paginating Travis build #{last_build_number}: #{e.message}"
    puts error_message
    sleep 20
    count+=1
    retry if count<5
  end

end

def getExistLargestBuildNumber(parent_dir)
  max=1
  Find.find(parent_dir) do |path|
    match=/\d+@/.match(path)
    temp=match[0][0..-2].to_i if match
    if temp&&temp>max
      max=temp
    end
  end
  max
end

def getBuilds(repo_id,)
  url="https://api.travis-ci.org/repo/#{repo_id}/builds?limit=25&offset=#{offset}"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the repo builds list of #{repo_name} at #{url}: #{$!}"
    retry
  end
end

def getTravis(repo_name)
  @parent_dir=File.join('..','build_logs',repo_name.gsub(/\//,'@'))
  FileUtils.mkdir_p(@parent_dir) unless File.exist?(@parent_dir)
  repo_slug=repo_name.sub(/\//,'%2F')
  begin
    f=open("https://api.travis-ci.org/repo/#{repo_slug}",'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the repo id of #{repo_name}: #{$!}"
    retry
  end
  repo_id=j['id']
  p f
  puts JSON.pretty_generate(j)
end

def eachRepository(input_CSV)
  #CSV.foreach(input_CSV,headers:false) do |row|
  #  getTravis("#{row[0]}") #if row[2].to_i>=1000
  #end
  getTravis('square/okhttp')
end
eachRepository(ARGV[0])
