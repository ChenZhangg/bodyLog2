require 'fileutils'
require 'travis'
require 'csv'
require 'travis/client'
require 'find'
def findRepository(repoName)
  i=0 
  begin 
    client = Travis::Client.new 
    repository=client.repo(repoName)
  rescue
    puts "findRepository #{$!}"
    client.clear_cache!
    repository=nil
    i+=1
    sleep 60
    retry if i<5
  end
  return repository
end

def getLastBuildNumber(repository)
  i=0
  begin
    lastBuildNumber=repository.last_build.number
  rescue
    puts "getLastBuildNumber #{$!}"
    lastBuildNumber=nil
    i+=1
    sleep 60
    retry if i<20
  end
  return lastBuildNumber
end

def getBuild(repository,number)
  i=0
  begin
    build=repository.build(number)
  rescue
    puts "getBuild #{$!}"
    build=nil
    sleep 60
    i+=1
    retry if i<5
  end
  return build
end

def getJobs(build)
  i=0
  begin
    jobs=build.jobs
  rescue
    puts "getJobs #{$!}"
    jobs=nil
    sleep 60
    i+=1
    retry if i<5
  end
  return jobs
end

def getLog(job)
  i=0
  begin
    log=job.log.body
  rescue
    puts "getLog #{$!}"
    log=nil
    sleep 60
    i+=1
    retry if i<5
  end
  return log
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

def getRepositoryLog(repo)
  parent_dir=File.join('..','build_logs',repo.gsub(/\//,'@'))
  
  repository=findRepository(repo)
  return unless repository
  lastBuildNumber=getLastBuildNumber(repository)
  return unless lastBuildNumber
  return if lastBuildNumber.to_i<1000
  FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
  firstBuildNumber=getExistLargestBuildNumber(parent_dir)
  for i in firstBuildNumber..lastBuildNumber.to_i
    build=getBuild(repository,i)
    next unless build
    jobs=getJobs(build)
    next unless jobs
    jobs.each do |job|
      name=File.join(parent_dir, "#{job.number.gsub(/\./,'@')}.log")
      puts name
      next if File.exist?(name)&&(File.size?(name)!=nil)    
      File.open(name,'w') do |file|
        log=getLog(job)   
        file.write(log)
      end
    end
  end

end

def eachRepository(input_CSV)
  CSV.foreach(input_CSV,headers:false) do |row|
     getRepositoryLog("#{row[0]}") if row[2].to_i>=1000
  end
end
eachRepository(ARGV[0])
