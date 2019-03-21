require 'json'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'activerecord-import'
require 'thread'
require 'travis'
require 'date'
class Build < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.131.252.160",
      username: "root",
      password: "root",
      database: "zc",
      encoding: "utf8mb4",
      collation: "utf8mb4_bin"
  )
end

class Repository < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.131.252.160",
      username: "root",
      password: "root",
      database: "zc",
      encoding: "utf8mb4",
      collation: "utf8mb4_bin"
  )
end
#rsync -av fdse@10.141.221.86:/home/fdse/user/zc/bodyLog2/  /home/fdse/user/zc/bodyLog2 
def rescue_build(repo_slug, build_number, hash)
  count = 0
  begin
    trepo = Travis::Repository.find(repo_slug)
    tbuild = trepo.build(build_number)
    hash[:build_id] = tbuild.id

    hash[:state] = tbuild.state
    hash[:duration] = tbuild.duration
    hash[:event_type] = tbuild.push? ? "push" : nil

    hash[:pull_request_title] = tbuild.pull_request_title
    hash[:pull_request_number] = tbuild.pull_request_number
    hash[:started_at] = tbuild.started_at ? DateTime.parse(tbuild.started_at.to_s).new_offset(0) : nil
    hash[:finished_at] = tbuild.finished_at ? DateTime.parse(tbuild.finished_at.to_s).new_offset(0) : nil

    hash[:repo_id] = trepo.id
    hash[:repo_name] = trepo.name
    hash[:repo_slug] = trepo.slug

    hash[:branch_name] = tbuild.branch_info
    hash[:tag] = nil#j['tag'] ? j['tag']['name'] : nil


    commit = tbuild.commit
    hash[:commit_id] =  tbuild.commit_id
    hash[:commit_sha] =  commit.sha
    hash[:commit_ref] = 'refs/heads/' + commit.branch
    hash[:commit_message] =  commit.message
    hash[:commit_compare_url] =  commit.compare_url
    hash[:commit_committed_at] = commit.committed_at ? DateTime.parse(commit.committed_at.to_s).new_offset(0) : nil

    hash[:jobs] = tbuild.jobs
    hash[:jobs_number] = tbuild.jobs.length

    hash[:build_stages] =  nil#j['stages']
    hash[:user_id] = nil#j['created_by'] ? j['created_by']['id'] : nil
    hash[:user_login] = nil#j['created_by'] ? j['created_by']['login'] : nil
    hash[:pdated_at] = nil#j['updated_at']

    hash[:parse_error_flag] = true
  rescue
    count += 1
    sleep 5
    retry if count < 5
  end
end

def parse_build_json_file(build_file_path, repository_id)
  hash = Hash.new
  hash[:repository_id] = repository_id
  match = /json_files\/(.+)\/build@(.+)\.json/.match build_file_path
  return unless match
  repo_name, build_number = match[1].sub(/@/, '/'), match[2].to_i
  hash[:repo_slug] = repo_name
  hash[:number] = build_number
  hash[:repository_id] = repository_id
  begin
    j = JSON.parse IO.read(build_file_path)
    hash[:build_id] = j['id']
    hash[:repository_id] = repository_id
    hash[:number] = j['number'].to_i
    hash[:state] = j['state']
    hash[:duration] = j['duration']
    hash[:event_type] = j['event_type']
    hash[:previous_state] = j['previous_state']
    hash[:pull_request_title] = j['pull_request_title']
    hash[:pull_request_number] = j['pull_request_number'].to_i
    hash[:started_at] = j['started_at'] ? DateTime.parse(j['started_at']).new_offset(0) : nil
    hash[:build_finished_at] = j['finished_at'] ? DateTime.parse(j['finished_at']).new_offset(0) : nil

    hash[:repo_id] = j['repository'] ? j['repository']['id'] : nil
    hash[:repo_name] = j['repository'] ? j['repository']['name'] : nil
    hash[:repo_slug] = j['repository'] ? j['repository']['slug'] : nil

    hash[:build_branch] = j['branch'] ? j['branch']['name'] : nil

    hash[:tag] = j['tag']

    hash[:commit_id] = j['commit'] ? j['commit']['id'] : nil
    hash[:commit_sha] = j['commit'] ? j['commit']['sha'] : nil
    hash[:commit_ref] = j['commit'] ? j['commit']['ref'] : nil
    hash[:commit_message] = j['commit'] ? j['commit']['message'] : nil
    hash[:commit_compare_url] = j['commit'] ? j['commit']['compare_url'] : nil
    hash[:commit_committed_at] = (j['commit'] && j['commit']['committed_at']) ? DateTime.parse(j['commit']['committed_at']).new_offset(0) : nil

    hash[:jobs] = j['jobs']
    hash[:jobs_number] = j['jobs'].length

    hash[:stages] = j['stages']

    hash[:user_id] = j['created_by'] ? j['created_by']['id'] : nil
    hash[:user_login] = j['created_by'] ? j['created_by']['login'] : nil

    hash[:build_updated_at] = j['updated_at'] ? DateTime.parse(j['updated_at']).new_offset(0) : nil
    hash[:parse_error_flag] = false
  rescue
    puts  $!
    puts $@
    puts build_file_path
    rescue_build(repo_slug, build_number, hash)
  end
  @result_queue.enq hash
end

def thread_init
  consumer = Thread.new do
    id = 0
    loop do
      bulk = []
      hash = nil
      200.times do
        hash = @result_queue.deq
        break if hash == :END_OF_WORK
        id += 1
        hash[:id] = id
        bulk << Build.new(hash)
      end
      Build.import bulk
      break if hash == :END_OF_WORK
    end
  end

  threads = []
  126.times do
    thread = Thread.new do
      loop do
        h = @input_queue.deq
        break if h == :END_OF_WORK
        parse_build_json_file h[:build_file_path], h[:repository_id]
      end
    end
    threads << thread
  end
  [consumer, threads]
end

def scan_json_files(json_files_path)
  consumer, threads = thread_init

  Repository.where("id >= ? AND builds >= ? AND stars>= ?", 0, 50, 25).find_each do |repo|
    puts "Scan repo: #{repo.repo_name}"
    repo_path = File.join(json_files_path, repo.repo_name.sub(/\//, '@'))
    Dir.foreach(repo_path) do |build_file_name|
      next if build_file_name !~ /build@.+/
      build_file_path = File.join(repo_path, build_file_name)
      p build_file_path
      hash = Hash.new
      hash[:build_file_path] = build_file_path
      hash[:repository_id] = repo.id
      @input_queue.enq hash
    end
  end
  126.times do
    @input_queue.enq :END_OF_WORK
  end
  threads.each { |t| t.join }
  @result_queue.enq :END_OF_WORK
  consumer.join
  puts "Scan Over"
end

Thread.abort_on_exception = true
json_file_path = ARGV[0] || '../json_files'
@result_queue = SizedQueue.new(200)
@input_queue = SizedQueue.new(300)
scan_json_files json_file_path
