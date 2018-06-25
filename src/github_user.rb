require_relative 'temp_job_datum'
require 'fileutils'
require 'open-uri'
require 'json'
require 'thread'

@parent_dir = File.expand_path(File.join('..', 'user_json_files'), File.dirname(__FILE__))
@github_dir = File.expand_path(File.join('..', 'github'), File.dirname(__FILE__))
@password = 'cumtzc04091751'
@account = 'zhangch1991425@163.com'
def thread_init
  @in_queue = SizedQueue.new(30)
  threads = []
  30.times do
    thread = Thread.new do
      loop do
        travis_user_id = @in_queue.deq
        break if travis_user_id == :END_OF_WORK
        get_user_json(travis_user_id)
      end
    end
    threads << thread
  end
  threads
end

def get_user_json(travis_user_id)
  url = "https://api.travis-ci.org/user/#{travis_user_id}"
  count = 0
  j = nil
  begin
    open(url,'Travis-API-Version'=>'3','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ') { |f| j = JSON.parse(f.read) }
  rescue
    puts "Failed to get the user info at #{url}: #{$!}"
    j = nil
    count += 1
    message = $!.message
    sleep 20 if message.include?('429')
    retry if !message.include?('404') && count<50
  end
  return unless j
  file_name = File.join(@parent_dir, "#{j['id']}@#{j['login']}.json")

  unless File.size?(file_name)
    File.open(file_name, 'w') do |file|
      file.puts(JSON.pretty_generate(j))
    end
  end
  puts "#Download from #{url} to #{file_name}"
end

def travis_user_list
  threads = thread_init
  FileUtils.mkdir_p(@parent_dir) unless File.exist?(@parent_dir)
  TempJobDatum.select(:created_by_id).distinct.each do |job|
    @in_queue.enq job.created_by_id
  end
  30.times do
    @in_queue.enq :END_OF_WORK
  end
  threads.each { |t| t.join }
  puts "Scan Over"
end

def get_github_user_json(travis_id, user_name)
  url = "https://api.github.com/users/#{user_name}"
  j = nil
  count = 0
  begin
    open(url,:http_basic_authentication=>[@account, @password]) { |f| j = JSON.parse(f.read) }
    #puts "x-ratelimit-remaining: #{f.meta["x-ratelimit-remaining"]}"
  rescue =>e
    puts "cannot open #{url}\n#{e.message}"
    j = nil
    sleep 20
    count += 1
    retry if count < 20
  end
  return unless j
  file_name = File.join(@github_dir, "#{travis_id}@#{user_name}.json")

  unless File.size?(file_name)
    File.open(file_name, 'w') do |file|
      file.puts(JSON.pretty_generate(j))
    end
  end
  puts "#Download from #{url} to #{file_name}"
end

def thread_init_github
  @in_queue = SizedQueue.new(30)
  threads = []
  5.times do
    thread = Thread.new do
      loop do
        hash = @in_queue.deq
        break if hash == :END_OF_WORK
        get_github_user_json(hash[:travis_id], hash[:user_name])
      end
    end
    threads << thread
  end
  threads
end

def scan_user_json_files
  threads = thread_init_github
  FileUtils.mkdir_p(@github_dir) unless File.exist?(@github_dir)
  Dir.foreach(@parent_dir) do |file|
    next if file !~ /.+@.+/
    json_file_path = File.join(@parent_dir, file)
    j = nil
    File.open(json_file_path, 'r') do |f|
      j = JSON.parse(f.read)
    end
    hash = Hash.new
    hash[:travis_id] = j['id']
    hash[:user_name] = j['login']
    @in_queue.enq hash
  end
  5.times do
    @in_queue.enq :END_OF_WORK
  end
  threads.each { |t| t.join }
  puts "Scan Over"
end
#travis_user_list
scan_user_json_files