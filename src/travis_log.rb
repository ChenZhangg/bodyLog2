require 'travis'
require 'open-uri'
require 'json'
require 'csv'
require 'fileutils'
require 'uri'
require 'find'
require 'open_uri_redirections'
require_relative 'travis_java_repository'

module DownloadLog
  def self.get_log(job_id)
    job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job_id}/log.txt"
    count = 0
    f = nil
    begin
      if job_log_url.include?('amazonaws')
        open(job_log_url) { |o| f = o.read }
      else
        open(job_log_url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ','Accept'=> 'text/plain',:allow_redirections => :all) { |o| f = o.read }
      end
    rescue => e
      puts "Retrying, #{count} times fail to download job log #{job_log_url}: #{e.message}"
      job_log_url = "http://api.travis-ci.org/job/#{job_id}/log" # if e.message.include?('403')
      f = nil
      sleep 20
      count += 1
      retry if count < 5
    end
    f
  end

  def self.parse_job_json_file(job_file_path)
    log_file_path = job_file_path.sub(/json_files/, 'build_logs').sub(/job@/,'').sub(/\.json/,'.log')
    puts "#{job_file_path}\n#{log_file_path}\n\n"
    return if File.size?(log_file_path)
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
    puts "Download log into #{log_file_path}"

    File.open(log_file_path, 'w') do |file|
      file.puts(f)
    end
  end

  def self.thread_init
    @queue = SizedQueue.new(31)
    threads = []
    31.times do
      thread = Thread.new do
        loop do
          job_file_path = @queue.deq
          break if job_file_path == :END_OF_WORK
          parse_job_json_file(job_file_path)
        end
      end
      threads << thread
    end
    threads
  end

  def self.scan_json_files(json_files_path, id)
    threads = thread_init
    TravisJavaRepository.where("id >= ? AND builds >= ? AND stars>= ?", id, 50, 25).find_each do |repo|
      repo_name = repo.repo_name
      puts "Scan project #{repo_name}"
      repo_json_path = File.join(json_files_path, repo_name.sub(/\//,'@'))
      #next unless File.exist? repo_json_path
      repo_log_path = repo_json_path.sub(/json_files/, 'build_logs')
      FileUtils.mkdir_p(repo_log_path) unless File.exist?(repo_log_path)
      Dir.foreach(repo_json_path) do |job_file_name|
        next if job_file_name !~ /job@.+@.+/
        job_file_path = File.join(repo_json_path, job_file_name)
        @queue.enq job_file_path
      end
    end
    31.times do
      @queue.enq :END_OF_WORK
    end
    threads.each { |t| t.join }
    puts "=====================Scan over==================="
  end

  def self.run
    Thread.abort_on_exception = true
    json_files_path = File.expand_path(File.join('..', 'json_files'), File.dirname(__FILE__))
    scan_json_files(json_files_path, 0)
  end
end
DownloadLog.run