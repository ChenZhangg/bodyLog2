require 'travis'
require 'open-uri'
require 'json'
require 'csv'
require 'fileutils'
require 'uri'
require 'net/http'


def downloadJob(job)
  job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job}/log.txt"
  puts job_log_url
  uri=URI.parse(job_log_url)
  response=Net::HTTP.get_response(uri)
  log=response.body
  puts job_log_url
  puts log
end

def jobLogs(build,sha)
  jobs=build['job_ids']
  jobs.each do |job|
    downloadJob(job)
  end 
end

def getBuild(builds,build)
  commit=builds['commits'].find{|x| x['id']==build['commit_id']}
  jobLogs(build,commit['sha'])
end

def paginateBuild(last_build_number,repo_id)
  count=0
  begin
    url="https://api.travis-ci.org/builds?after_number=#{last_build_number}&repository_id=#{repo_id}"
    resp=open(url,'Content-Type'=>'application/json','Accept'=>'application/vnd.travis-ci.2+json')
    builds=JSON.parse(resp.read)
    #puts JSON.pretty_generate(builds)
    builds['builds'].each do |build|
      getBuild(builds,build)
    end
  rescue  Exception => e
    error_message = "Retrying, but Error paginating Travis build #{last_build_number}: #{e.message}"
    puts error_message
    sleep 60
    count+=1
    retry if count<10
  end

end

def getTravis(repo)
  @parent_dir=File.join('..','build_logs',repo.gsub(/\//,'@'))
  FileUtils.mkdir_p(@parent_dir) unless File.exist?(@parent_dir)
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

    (0..last_build_number).select { |x| x % 25 == 0 }.reverse_each do |last_build|
       paginateBuild(last_build, repo_id)
    end
  rescue Exception => e
    error_message = "Retrying, but Error getting Travis builds for #{repo}: #{e.message}"
    puts error_message
    sleep 60
    count+=1
    retry if count<10
  end

end

def eachRepository(input_CSV)
  CSV.foreach(input_CSV,headers:false) do |row|
    getTravis("#{row[0]}") if row[2].to_i>=1000
  end
end
eachRepository('repo0.csv')

