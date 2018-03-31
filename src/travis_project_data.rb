require 'csv'
require 'open-uri'
require 'json'
require 'fileutils'

def getJob(job_id,parent_dir)
  url="https://api.travis-ci.org/job/#{job_id}"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the job at #{url}: #{$!}"
    retry
  end

  file_name=File.join(parent_dir, "job@#{j['number'].sub(/\./,'@')}.json")

  unless File.exist?(file_name)&&(File.size?(file_name)!=nil)
    File.open(file_name,'w') do |file|
      file.puts(JSON.pretty_generate(j))
    end
  end
  puts "#Download from #{url} to #{file_name}"
end

def getBuild(build_id,parent_dir)
  url="https://api.travis-ci.org/build/#{build_id}"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the build at #{url}: #{$!}"
    retry
  end
  #puts JSON.pretty_generate(j)

  file_name=File.join(parent_dir, "build@#{j['number']}.json")

  unless File.exist?(file_name)&&(File.size?(file_name)!=nil)
    File.open(file_name,'w') do |file|
      file.puts(JSON.pretty_generate(j))
    end
  end

  puts "#Download from #{url} to #{file_name}"

  jobs=j['jobs']
  jobs.each do |job|
    getJob(job['id'],parent_dir)
  end

end

def getBuilds(repo_id,offset,parent_dir)
  threads=[]
  while offset
    url="https://api.travis-ci.org/repo/#{repo_id}/builds?limit=25&offset=#{offset}"
    begin
      f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
      j= JSON.parse f.read
    rescue
      puts "Failed to get the repo builds list at #{url}: #{$!}"
      retry
    end
    #puts JSON.pretty_generate(j)
    offset=j['@pagination']['next']?j['@pagination']['next']['offset']:nil
    builds=j['builds']

    builds.each do |build|
      thr=Thread.new(build['id'],parent_dir) do |build_id,parent_dir|
        getBuild(build_id,parent_dir)
      end
      threads<<thr
      loop do
        count=Thread.list.count{|thread| thread.alive? }
        break if count <= 50
      end
    end
    threads.delete_if{|thread| !thread.alive?}
  end
  threads.each do |thr|
    thr.join if thr.alive?
  end
end

def getRepoID(repo_name,parent_dir)
  repo_slug=repo_name.sub(/\//,'%2F')
  begin
    f=open("https://api.travis-ci.org/repo/#{repo_slug}",'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the repo id of #{repo_name}: #{$!}"
    retry
  end
  id=j['id']
  getBuilds(id,0,parent_dir)
  #puts JSON.pretty_generate(j)
end

def scanProjectsInCsv(file)
  flag=true
  CSV.foreach(file) do |row|
    repo_name=row[0]
    flag=false  if repo_name.include?('presto')
    next if flag
    parent_dir=File.join('..','json_files',repo_name.gsub(/\//,'@'))
    FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
    getRepoID(repo_name,parent_dir)
  end
end

scanProjectsInCsv('Above1000WithTravisAbove1000.csv')
