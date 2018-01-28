
require 'open-uri'
require 'json'
require 'csv'
require 'fileutils'
require 'uri'
require 'net/http'
@input_CSV="/home/zc/project/travisLogAnalysis/data/repositoryUseTravis.csv"

def downloadJob(job)
  job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job}/log.txt"
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

def paginateBuild(build_number,repo_id)
  url="https://api.travis-ci.org/builds?after_number=#{build_number}&repository_id=#{repo_id}"
  resp=open(url,'Content-Type'=>'application/json','Accept'=>'application/vnd.travis-ci.2+json')
  builds=JSON.parse(resp.read)
  builds['builds'].each do |build|
    getBuild(builds,build)
  end
end

def getRepositoryLog(repo,last_build_number)
  @parent_dir=File.join('..','build_logs',repo.gsub(/\//,'@'))
  FileUtils.mkdir_p(@parent_dir) unless File.exist?(@parent_dir)
  repo_id=JSON.parse(open("https://api.travis-ci.org/repos/#{repo}").read)['id']
  
  while (last_build_number-1)%25!=0 do
    last_build_number=last_build_number+1
  end
  
  (2..last_build_number).select{|v| (v-1)%25==0}.reverse_each do |build_number|
      paginateBuild(build_number,repo_id) 
  end
end

def eachRepository(input_CSV)
  CSV.foreach(@input_CSV,headers:false) do |row|
      getRepositoryLog("#{row[0]}",row[2].to_i) if row[2].to_i >= 1000
  end
end
eachRepository(ARGV[0])
