require 'csv'
require 'open-uri'
require 'json'
require 'fileutils'
require_relative 'travis_java_repository'
module DownloadJSON
  def self.get_job_json(job_id, parent_dir)
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

    unless File.size?(file_name)
      File.open(file_name, 'w') do |file|
        file.puts(JSON.pretty_generate(j))
      end
    end
    puts "#Download from #{url} to #{file_name}"
  end

  def self.get_build_json(build_id, parent_dir)
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
    File.open(file_name,'w') do |file|
      file.puts(JSON.pretty_generate(j))
    end
    puts "#Download from #{url} to #{file_name}"

    jobs = j['jobs']
    jobs.each do |job|
      get_job_json(job['id'], parent_dir)
    end

  end

  def self.get_builds_list(repo_id, offset, parent_dir)
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
        build_number = build['number']
        file_name = File.join(parent_dir, "build@#{build_number}.json")
        next if File.size?(file_name)
        get_build_json(build['id'], parent_dir)
      end
      builds = nil
    end    
  end

  def self.get_repo_id(repo_name, parent_dir)
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

  def self.thread_init
    @queue = SizedQueue.new(31)
    threads = []
    31.times do
      thread = Thread.new do
        loop do
          hash = @queue.deq
          break if hash == :END_OF_WORK
          get_repo_id(hash[:repo_name], hash[:parent_dir])
        end
      end
      threads << thread
    end
    threads
  end

  def self.scan_repos(id, builds, stars)
    threads = thread_init
    TravisJavaRepository.where("id >= ? AND builds >= ? AND stars>= ?", id, builds, stars).find_each do |repo|
      repo_name = repo.repo_name
      parent_dir = File.join('..', 'json_files', repo_name.gsub(/\//,'@'))
      FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)
      hash = Hash.new
      hash[:repo_name] = repo_name
      hash[:parent_dir] = parent_dir
      @queue.enq hash
      puts "Scan project  id=#{repo.id}   #{repo_name} builds=#{repo.builds}   stars=#{repo.stars}"
    end
    31.times do
      @queue.enq :END_OF_WORK
    end
    threads.each { |t| t.join }
    puts "Scan Over"
  end

  def self.run
    Thread.abort_on_exception = true
    scan_repos(1, 50, 25)
  end  
end
DownloadJSON.run