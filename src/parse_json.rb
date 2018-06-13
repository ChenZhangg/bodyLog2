require 'json'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'activerecord-import'
require 'thread'
require 'date'
require_relative 'travis_java_repository'
require_relative 'temp_job_datum'

module ParseJson
  def self.rescue_job(repo_name, job_number, hash)
    count = 0
    begin
      trepo = Travis::Repository.find(repo_name)
      tjob = trepo.job(job_number)
      hash[:job_id] = tjob.id
      hash[:job_allow_failure] = tjob.allow_failure
      hash[:job_state] = tjob.state
      hash[:job_started_at] = tjob.started_at ? DateTime.parse(tjob.started_at.to_s).new_offset(0) : nil
      hash[:job_finished_at] = tjob.finished_at ? DateTime.parse(tjob.finished_at.to_s).new_offset(0) : nil
      hash[:job_queue] = tjob.queue
      hash[:job_stage] = nil
      hash[:job_created_at] = nil#tjob.created_at
      hash[:job_updated_at] = nil#tjob.updated_at

      commit = tjob.commit
      hash[:commit_id] =  tjob.commit_id
      hash[:commit_sha] =  commit.sha
      hash[:commit_ref] = commit.branch
      hash[:commit_message] =  commit.message
      hash[:commit_compare_url] =  commit.compare_url
      hash[:commit_committed_at] = commit.committed_at ? DateTime.parse(commit.committed_at.to_s).new_offset(0) : nil
    rescue
      count += 1
      sleep 5
      retry if count < 5
    end
  end

  def self.rescue_build(repo_name, build_number, hash)
    count = 0
    begin
      trepo = Travis::Repository.find(repo_name)
      tbuild = trepo.build(build_number)
      hash[:build_id] = tbuild.id
      hash[:build_state] = tbuild.state
      hash[:build_duration] = tbuild.duration
      hash[:build_event_type] = tbuild.push? ? "push" : "pull_request"
      hash[:pull_request_title] = tbuild.pull_request_title
      hash[:pull_request_number] = tbuild.pull_request_number
      hash[:build_started_at] = tbuild.started_at ? DateTime.parse(tbuild.started_at.to_s).new_offset(0) : nil
      hash[:build_finished_at] = tbuild.finished_at ? DateTime.parse(tbuild.finished_at.to_s).new_offset(0) : nil
      hash[:build_branch] = tbuild.branch_info
      hash[:build_tag] = nil#j['tag'] ? j['tag']['name'] : nil

      hash[:build_stages] =  nil#j['stages']
      hash[:created_by_id] = nil#j['created_by'] ? j['created_by']['id'] : nil
      hash[:created_by_login] = nil#j['created_by'] ? j['created_by']['login'] : nil
      hash[:build_updated_at] = nil#j['updated_at']
    rescue
      count += 1
      sleep 5
      retry if count < 5
    end
  end

  def self.parse_job_json_file(job_file_path, repo_id)
    hash = Hash.new
    match = /json_files\/(.+)\/job@(.+)@(.+)\.json/.match job_file_path
    repo_name, build_number, job_number = match[1].sub(/@/, '/'), match[2].to_i, match[2] + '.' + match[3]
    hash[:repo_name] = repo_name
    hash[:job_number] = job_number
    hash[:travis_java_repository_id] = repo_id
    hash[:build_number] = build_number
    hash[:build_number_int] = build_number.to_i
    hash[:job_order_number] = match[3].to_i

    begin
      j = JSON.parse IO.read(job_file_path)
      hash[:job_id] = j['id']
      hash[:job_allow_failure] = j['allow_failure']
      hash[:job_state] = j['state']
      hash[:job_started_at] = j['started_at']? DateTime.parse(j['started_at']).new_offset(0) : nil
      hash[:job_finished_at] = j['finished_at'] ? DateTime.parse(j['finished_at']).new_offset(0) : nil
      hash[:job_queue] = j['queue']
      hash[:job_stage] = j['stage']
      hash[:job_created_at] = j['created_at'] ? DateTime.parse(j['created_at']).new_offset(0) : nil
      hash[:job_updated_at] = j['updated_at'] ? DateTime.parse(j['updated_at']).new_offset(0) : nil

      hash[:commit_id] = j['commit'] ? j['commit']['id'] : nil
      hash[:commit_sha] = j['commit'] ? j['commit']['sha'] : nil
      hash[:commit_ref] = j['commit'] ? j['commit']['ref'] : nil
      hash[:commit_message] = j['commit'] ? j['commit']['message'] : nil
      hash[:commit_compare_url] = j['commit'] ? j['commit']['compare_url'] : nil
      hash[:commit_committed_at] = (j['commit'] && j['commit']['committed_at']) ? DateTime.parse(j['commit']['committed_at']).new_offset(0) : nil
    rescue
      puts  $!
      puts $@
      puts job_file_path
      rescue_job(repo_name, job_number, hash)
    end

    begin
      build_file_path = job_file_path.sub(/(?<=\/)job(?=@)/, 'build').sub(/(?<=\d)@\d+(?=\.json)/, '')
      j = JSON.parse IO.read(build_file_path)
      hash[:build_id] = j['id']
      hash[:build_state] = j['state']
      hash[:build_duration] = j['duration']
      hash[:build_event_type] = j['event_type']
      hash[:pull_request_title] = j['pull_request_title']
      hash[:pull_request_number] = j['pull_request_number']
      hash[:build_started_at] = j['started_at'] ? DateTime.parse(j['started_at']).new_offset(0) : nil
      hash[:build_finished_at] = j['finished_at'] ? DateTime.parse(j['finished_at']).new_offset(0) : nil
      hash[:build_branch] = j['branch'] ? j['branch']['name'] : nil
      hash[:build_tag] = j['tag'] ? j['tag']['name'] : nil

      hash[:build_stages] = j['stages']
      hash[:created_by_id] = j['created_by'] ? j['created_by']['id'] : nil
      hash[:created_by_login] = j['created_by'] ? j['created_by']['login'] : nil
      hash[:build_updated_at] = j['updated_at'] ? DateTime.parse(j['updated_at']).new_offset(0) : nil
    rescue
      puts  $!
      puts $@
      puts job_file_path
      rescue_build(repo_name, build_number, hash)
    end
    @out_queue.enq hash
  end

  def self.thread_init
    @in_queue = SizedQueue.new(31)
    @out_queue = SizedQueue.new(200)
    consumer = Thread.new do
      id = 0
      loop do
        bulk = []
        hash = nil
        200.times do
          hash = @out_queue.deq
          break if hash == :END_OF_WORK
          id += 1
          hash[:id] = id
          bulk << TempJobDatum.new(hash)
        end
        TempJobDatum.import bulk
        break if hash == :END_OF_WORK
      end
    end

    threads = []
    31.times do
      thread = Thread.new do
        loop do
          hash = @in_queue.deq
          break if hash == :END_OF_WORK
          parse_job_json_file hash[:job_file_path], hash[:travis_java_repository_id]
        end
      end
      threads << thread
    end
    [consumer, threads]
  end

  def self.scan_json_files(json_files_path)
    consumer, threads = thread_init
    TravisJavaRepository.where("id >= ? AND builds >= ? AND stars>= ?", 1, 50, 25).find_each do |repo|
      puts "Scan repo: #{repo.repo_name}"
      repo_json_path = File.join(json_files_path, repo.repo_name.sub(/\//, '@'))
      repo_id = repo.id
      Dir.foreach(repo_json_path) do |job_file_name|
        next if job_file_name !~ /job@.+@.+/
        job_file_path = File.join(repo_json_path, job_file_name)
        hash = Hash.new
        hash[:job_file_path] = job_file_path
        hash[:travis_java_repository_id] = repo_id
        @in_queue.enq hash
      end
    end
    31.times do
      @in_queue.enq :END_OF_WORK
    end
    threads.each { |t| t.join }
    @out_queue.enq(:END_OF_WORK)
    consumer.join
    puts "Scan Over"
  end

  def self.run
    Thread.abort_on_exception = true
    json_files_path = File.expand_path(File.join('..', 'json_files'), File.dirname(__FILE__))
    scan_json_files json_files_path
  end
end
ParseJson.run