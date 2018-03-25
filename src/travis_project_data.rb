require 'csv'
require 'open-uri'
require 'json'
require 'fileutils'
require 'mysql2'

@mutex=Mutex.new
def getJob(job_id,hash,parent_dir)
  url="https://api.travis-ci.org/job/#{job_id}"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the job at #{url}: #{$!}"
    #retry
  end
  hash[:job_id]=j['id']
  hash[:job_allow_failure]=j['allow_failure']
  hash[:job_number]=j['number']
  hash[:job_state]=j['state']
  hash[:job_started_at]=j['started_at']
  hash[:job_finished_at]=j['finished_at']
  hash[:job_queue]=j['queue']
  hash[:job_created_at]=j['created_at']
  hash[:job_updated_at]=j['updated_at']

  file_name=File.join(parent_dir, "job@#{j['number'].sub(/\./,'@')}.json")
  File.open(file_name,'w') do |file|
    file.puts(JSON.pretty_generate(j))
  end
  @mutex.synchronize do
    insertData(hash)
  end
  #puts JSON.pretty_generate(j)
end

def getBuild(build_id,hash,parent_dir)
  url="https://api.travis-ci.org/build/#{build_id}"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the build at #{url}: #{$!}"
    #retry
  end
  #puts JSON.pretty_generate(j)
  hash[:build_id]=j['id']
  hash[:build_number]=j['number']
  hash[:build_state]=j['state']
  hash[:build_duration]=j['duration']
  hash[:build_event_type]=j['event_type']
  hash[:pull_request_title]=j['pull_request_title']
  hash[:pull_request_number]=j['pull_request_number']
  hash[:build_started_at]=j['started_at']
  hash[:build_finished_at]=j['finished_at']
  hash[:branch]=j['branch']['name']
  hash[:tag]=j['tag']
  hash[:commit_id]=j['commit']['id']
  hash[:commit_sha]=j['commit']['sha']
  hash[:commit_ref]=j['commit']['id']
  hash[:commit_message]=j['commit']['message']
  hash[:commit_compare_url]=j['commit']['compare_url']
  hash[:commit_committed_at]=j['commit']['committed_at']
  hash[:created_id]=j['created_by']['id']
  hash[:created_login]=j['created_by']['login']
  hash[:build_updated_at]=j['updated_at']

  file_name=File.join(parent_dir, "build@#{j['number']}.json")
  File.open(file_name,'w') do |file|
    file.puts(JSON.pretty_generate(j))
  end

  jobs=j['jobs']
  jobs.each do |job|
    getJob(job['id'],hash,parent_dir)
  end

end

def getBuilds(repo_id,offset,hash,parent_dir)
  url="https://api.travis-ci.org/repo/#{repo_id}/builds?limit=25&offset=#{offset}"
  begin
    f=open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the repo builds list of #{repo_name} at #{url}: #{$!}"
    retry
  end
  #puts JSON.pretty_generate(j)
  next_offset=j['@pagination']['next']['offset'] if j['@pagination']['next']
  builds=j['builds']

  threads=[]
  builds.each do |build|
    thr=Thread.new(build['id'],hash.dup) do |id,hash|
      getBuild(build['id'],hash,parent_dir)
    end
    threads<<thr
  end
  threads.each { |thr| thr.join }

  flag=true
  while flag
    flag=false
    sleep 1
    threads.each do |thr|
      if false!=thr.status
        flag=true
        break
      end
    end
  end

  getBuilds(repo_id,next_offset,hash,parent_dir) if next_offset
end

def getRepoID(repo_name,hash,parent_dir)
  repo_slug=repo_name.sub(/\//,'%2F')
  begin
    f=open("https://api.travis-ci.org/repo/#{repo_slug}",'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the repo id of #{repo_name}: #{$!}"
    retry
  end
  id=j['id']
  hash[:repo_name]=repo_name
  hash[:repo_id]=id
  #p id.class
  getBuilds(id,0,hash,parent_dir)
  #puts JSON.pretty_generate(j)
end

def scanProjectsInCsv(file)
  CSV.foreach(file) do |row|
    repo_name=row[0]
    parent_dir=File.join('..','json_files',repo_name.gsub(/\//,'@'))
    FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
    hash=Hash.new
    getRepoID(repo_name,hash,parent_dir)

  end
end


def insertData(hash)
  id=hash[:job_id]
  statement = CLIENT.prepare('INSERT INTO travis0(job_id) VALUES(?);')
  statement.execute(id)
  hash.each do |key,value|
    next if key==:job_id
    begin
      statement = CLIENT.prepare("UPDATE travis0 SET #{key.to_s}=? WHERE job_id=#{id};")
      statement.execute(value)
    rescue
      puts "Failed to insert #{key} : #{value} bacause #{$!}"
    end
  end
end

CLIENT = Mysql2::Client.new(:host => 'localhost', :username => 'root',:password=>'root',:encoding => 'utf8mb4')
CLIENT.query('ALTER DATABASE zc CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;')
CLIENT.query('USE zc')
CLIENT.query('ALTER Table zc.travis0 CONVERT TO CHARACTER SET utf8;')
scanProjectsInCsv('Above1000WithTravisAbove1000.csv')
