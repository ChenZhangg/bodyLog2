require 'json'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'thread'

class JavaRepoBuildDatum < ActiveRecord::Base
  self.table_name = 'repository_java'
  establish_connection(
      adapter:  "mysql",
      host:     "localhost",
      username: "root",
      #password: "root",
      database: "zc"
  )
end

def parse_job_json_file(job_file_path)
  j=JSON.parse IO.read(job_file_path)
  hash=Hash.new
  hash[:repo_name]=j['repository']['slug']
  hash[:job_id]=j['id']
  hash[:job_allow_failure]=j['allow_failure']
  hash[:job_number]=j['number']
  hash[:job_state]=j['state']
  hash[:job_started_at]=j['started_at']
  hash[:job_finished_at]=j['finished_at']
  hash[:job_queue]=j['queue']
  hash[:job_stage]=j['stage']
  hash[:job_created_at]=j['created_at']
  hash[:job_updated_at]=j['updated_at']

  hash[:commit_id]=j['commit'] ? j['commit']['id'] : nil
  hash[:commit_sha]=j['commit'] ? j['commit']['sha'] : nil
  hash[:commit_ref]=j['commit'] ? j['commit']['ref'] : nil
  hash[:commit_message]=j['commit'] ? j['commit']['message'] : nil
  hash[:commit_compare_url]=j['commit'] ? j['commit']['compare_url'] : nil
  hash[:commit_committed_at]=j['commit'] ? j['commit']['committed_at'] : nil

  build_file_path=job_file_path.sub(/(?<=\/)job(?=@)/,'build').sub(/(?<=\d)@\d+(?=\.json)/,'')

  j=JSON.parse IO.read(build_file_path)

  hash[:build_id]=j['id']
  hash[:build_number]=j['number']
  hash[:build_state]=j['state']
  hash[:build_duration]=j['duration']
  hash[:build_event_type]=j['event_type']
  hash[:pull_request_title]=j['pull_request_title']
  hash[:pull_request_number]=j['pull_request_number']
  hash[:build_started_at]=j['started_at']
  hash[:build_finished_at]=j['finished_at']
  hash[:build_branch]=j['branch'] ? j['branch']['name'] : nil
  hash[:build_tag]=j['tag'] ? j['tag']['name'] : nil

  hash[:build_stages]=j['stages']
  hash[:created_by_id]=j['created_by'] ? j['created_by']['id'] : nil
  hash[:created_by_login]=j['created_by'] ? j['created_by']['login'] : nil
  hash[:build_updated_at]=j['updated_at']
  @queue.enq hash
  #puts JSON.pretty_generate(j)
end

def scan_json_files(json_files_path)
  threads=[]
  Dir.entries(json_files_path).select{|p| p =~ /.+@.+/}.each do |repo_name|
    repo_path=File.join(json_files_path,repo_name)
    Dir.entries(repo_path).select{|p| p =~ /job@.+@.+/}.sort_by!{|e| e.sub(/job@/,'').sub(/\.json/,'').sub(/@/,'.').to_f}.each do |job_file_name|
      job_file_path=File.join(repo_path,job_file_name)
      thr=Thread.new(job_file_path) do |job_file_path|
        parse_job_json_file job_file_path
      end

      threads<<thr
      loop do
        count=Thread.list.count{|thread| thread.alive? }
        break if count <= 100
      end
      threads.delete_if{|thread| !thread.alive?}
    end
  end

  threads.each{|thread| thread.join if thread.alive?}
end

json_file_path=ARGV[0]||'../json_files'

@queue = Queue.new
consumer = Thread.new do
  loop do
    hash = @queue.deq
    break if hash == :END_OF_WORK
    p hash
    #tjr=JavaRepoBuildDatum.create hash
  end
end

scan_json_files json_file_path
@queue.enq(:END_OF_WORK)
consumer.join