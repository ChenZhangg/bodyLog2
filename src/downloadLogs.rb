require 'travis'
require 'open-uri'
require 'json'
require 'csv'
require 'fileutils'
require 'uri'
require 'net/http'
require 'find'
=begin
def downloadJob(job)
  #job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job}/log.txt"
  job_log_url="http://api.travis-ci.org/jobs/#{job}/log"
  puts job_log_url
  uri=URI.parse(job_log_url)
  response=Net::HTTP.get_response(uri)
  puts response.code
  puts response.message
  response.each{|key,val| printf "%-14s = %-40.40s\n",key,val}
  log=response.body
  puts log
end

def jobLogs(build)
  jobs=build['job_ids']
  jobs.each do |job|
    #downloadJob(job)
  end 
end
=end
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

def getTravis(repo)
  @parent_dir=File.join('..','build_logs',repo.gsub(/\//,'@'))
  FileUtils.mkdir_p(@parent_dir) unless File.exist?(@parent_dir)
  first_build_number=getExistLargestBuildNumber(@parent_dir)
  count=0
  begin
    repository=Travis::Repository.find(repo)

    last_build_number=repository.last_build_number.to_i
    puts "Harvesting Travis build logs for #{repo} (#{last_build_number} builds)"

    while true do
      last_build_number = last_build_number + 1
      if last_build_number % 25 == 0
        break
      end
    end

    repo_id=JSON.parse(open("https://api.travis-ci.org/repos/#{repo}").read)['id']

    (first_build_number..last_build_number).select { |x| x % 25 == 0 }.each do |last_build|
       paginateBuild(last_build, repo_id)
    end
  rescue Exception => e
    error_message = "Retrying, but Error getting Travis builds for #{repo}: #{e.message}"
    puts error_message
    sleep 20
    count+=1
    retry if count<5
  end

end

def eachRepository(input_CSV)
  CSV.foreach(input_CSV,headers:false) do |row|
    getTravis("#{row[0]}") if row[2].to_i>=1000
  end
end
eachRepository(ARGV[0])
#eachRepository('repo0')
