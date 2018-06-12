require 'csv'
require 'open-uri'
require 'json'
require 'fileutils'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'

class TravisJavaRepository < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.131.252.160",
      username: "root",
      password: "root",
      database: "zc"
  )
end

def get_job_json(job_id, parent_dir)
  url = "https://api.travis-ci.org/job/#{job_id}"
  count = 0
  begin
    f = open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j= JSON.parse f.read
  rescue
    puts "Failed to get the job at #{url}: #{$!}"
    j = nil
    count += 1
    message = $!.message
    sleep 20 if message.include?('429')
    retry if !message.include?('404') && count<50
  end

  return unless j
  file_name = File.join(parent_dir, "job@#{j['number'].sub(/\./,'@')}.json")

  unless File.exist?(file_name) && File.size?(file_name)!=nil
    File.open(file_name, 'w') do |file|
      file.puts(JSON.pretty_generate(j))
    end
  end
  puts "#Download from #{url} to #{file_name}"
end

def get_build_json(build_id, parent_dir)
  url = "https://api.travis-ci.org/build/#{build_id}"
  begin
    f = open(url, 'Travis-API-Version' => '3', 'Authorization' => 'token C-cYiDyx1DUXq3rjwWXmoQ')
    j = JSON.parse f.read
  rescue
    puts "Failed to get the build at #{url}: #{$!}"
    sleep 20
    retry
  end
  #puts JSON.pretty_generate(j)

  file_name = File.join(parent_dir, "build@#{j['number']}.json")

  unless File.exist?(file_name) && File.size?(file_name)!=nil
    File.open(file_name,'w') do |file|
      file.puts(JSON.pretty_generate(j))
    end
  end

  puts "#Download from #{url} to #{file_name}"

  jobs = j['jobs']
  jobs.each do |job|
    get_job_json(job['id'], parent_dir)
  end

end

def get_builds_list(repo_id, offset, parent_dir)
  while offset
    url = "https://api.travis-ci.org/repo/#{repo_id}/builds?limit=25&offset=#{offset}"
    begin
      f = open(url, 'Travis-API-Version'=>'3', 'Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
      j = JSON.parse f.read
    rescue
      puts "Failed to get the repo builds list at #{url}: #{$!}"
      sleep 20
      retry
    end
    #puts JSON.pretty_generate(j)
    offset = j['@pagination']['next'] ? j['@pagination']['next']['offset'] : nil
    builds = j['builds']

    builds.each do |build|
      Thread.new(build['id'], parent_dir) do |build_id, parent_dir|
        get_build_json(build_id, parent_dir)
      end
      loop do
        break if Thread.list.count{ |thread| thread.alive? } <= 200
      end
    end
  end
  #Thread.list.each { |thread| thread.join if thread.alive? && thread != Thread.current}
end

def get_repo_id(repo_name, parent_dir)
  repo_slug = repo_name.sub(/\//,'%2F')
  count=0
  begin
    f = open("https://api.travis-ci.org/repo/#{repo_slug}",'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ')
    j = JSON.parse f.read
  rescue
    puts "Failed to get the repo id of #{repo_name}: #{$!}"
    sleep 20
    count += 1
    retry if count<50
    return
  end
  id = j['id']
  get_builds_list(id, 0, parent_dir)
  #puts JSON.pretty_generate(j)
end

def thread_init
  threads = []
  30.times do
    thread = Thread.new do
      loop do
        h = @job_queue.deq
        break if h == :END_OF_WORK
        compiler_error_message_slice h[:repo_name], h[:job_number], h[:java_repo_job_datum_id], h[:slice_segment]
      end
    end
    threads << thread
  end
end

def scan_mysql(builds, stars)
  TravisJavaRepository.where("builds >= ? AND stars>= ?", id, builds, stars).find_each do |repo|
    repo_name = repo.repo_name
    puts "Scan project  id=#{e.id}   #{repo_name} builds=#{repo.builds}   stars=#{repo.stars}"
    parent_dir = File.join('..', 'json_files', repo_name.gsub(/\//,'@'))
    FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
    get_repo_id(repo_name, parent_dir)
  end
end



Thread.abort_on_exception = true
scan_mysql(50, 25)
#scanProjectsInCsv('Above1000WithTravisAbove1000.csv')
