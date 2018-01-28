require 'fileutils'
require 'travis'
require 'csv'
def findRepository(repo)
  i=0
  begin
    repository=Travis::Repository.find(repo)
  rescue
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
    build=nil
    sleep 60
    i+=1
    retry if i<5
  end
  return build
end

def getLog(job)
  i=0
  begin
    log=job.log.body
  rescue
    log=nil
    sleep 60
    i+=1
    retry if i<5
  end
  return log
end

def getRepositoryLog(repo)
  parent_dir=File.join('..','build_logs',repo.gsub(/\//,'@'))
  #return if File.exist?(@parent_dir)
  
  repository=findRepository(repo)
  return unless repository
  lastBuildNumber=getLastBuildNumber(repository)
  return unless lastBuildNumber
  return if lastBuildNumber.to_i<1000
  FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
  for i in 1..lastBuildNumber.to_i
    build=getBuild(repository,i)
    next unless build
    build.jobs.each do |job|
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
     getRepositoryLog("#{row[0]}") if row[2].to_i!=0
  end
end
eachRepository(ARGV[0])
