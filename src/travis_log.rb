require 'travis'
require 'open-uri'
require 'json'
require 'csv'
require 'fileutils'
require 'uri'
require 'find'
require 'open_uri_redirections'


def get_log(job_id)
  job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job_id}/log.txt"
  count=0
  begin
    if job_log_url.include?('amazonaws')
      f = open(job_log_url)
    else
      f = open(job_log_url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ','Accept'=> 'text/plain',:allow_redirections => :all)
    end
  rescue => e
    puts "Retrying, #{count} times fail to download job log #{job_log_url}: #{e.message}"
    job_log_url = "http://api.travis-ci.org/job/#{job_id}/log" # if e.message.include?('403')
    f = nil
    sleep 20
    count+=1
    retry if count<5
  end
  f
end

def parse_job_json_file(job_file_path)
  begin
    j = JSON.parse IO.read(job_file_path)
    job_id = j['id']
  rescue
    regexp = /"number": "([.\d]+)"/
    IO.readlines(job_file_path).each do |line|
      break if regexp =~ line
    end
    job_id = $1
  end
  f = job_id ? get_log(job_id) : nil

  return unless f
  log_file_path = job_file_path.sub(/json_files/, 'build_logs').sub(/job@/,'').sub(/\.json/,'.log')
  puts "Download log into #{log_file_path}"
  return if File.exist?(log_file_path) && File.size?(log_file_path) != nil

  File.open(log_file_path, 'w') do |file|
    file.puts(f.read)
  end
end

def scan_json_files(json_files_path)

  flag = true
  flag_repo = 'deegree@deegree3'
  Dir.entries(json_files_path).select{ |p| p =~ /.+@.+/ }.sort_by!{ |e| File.mtime(File.join(json_files_path, e)) }.each do |repo_name|
    puts "Scan project #{repo_name}"
    flag = false if repo_name.include? flag_repo
    next if flag

    repo_path = File.join(json_files_path, repo_name)
    parent_dir = repo_path.sub(/json_files/, 'build_logs')
    FileUtils.mkdir_p(parent_dir) unless File.exist?(parent_dir)

    Dir.foreach(repo_path) do |job_file_name|
      next if job_file_name !~ /job@.+@.+/
      job_file_path = File.join(repo_path, job_file_name)
      Thread.new(job_file_path) do |job_file_path|
        parse_job_json_file job_file_path
      end
      loop do
        break if Thread.list.count{|thread| thread.alive? } <= 300
      end
    end
  end
  puts "=====================Scan over==================="
  Thread.list.each { |thread| thread.join if thread.alive? && thread != Thread.current}
end

Thread.abort_on_exception = true
json_files_path = ARGV[0] || '../json_files'

scan_json_files(json_files_path)