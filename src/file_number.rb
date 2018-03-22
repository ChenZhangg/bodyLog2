@maven_error_message='COMPILATION ERROR'
@gradle_error_message='Compilation failed'
@count=0
@count_one_project=0
@count_projects=0
def mavenOrGradle(log_file_path)
  f=IO.read log_file_path
  if f.include?(@maven_error_message) || f.include?(@gradle_error_message)
    puts log_file_path
    @count+=1
    @count_one_project+=1
    puts @count
  end

end


def traverseDir(build_logs_path)
  (Dir.entries(build_logs_path)).delete_if {|repo_name| /.+@.+/!~repo_name}.each do |repo_name|
    repo_path=File.join(build_logs_path,repo_name)
    puts "Scanning projects: #{repo_path}"
    @count_one_project=0
    Dir.entries(repo_path).delete_if {|log_file_name| /.+@.+/!~log_file_name}.sort_by!{|e| e.sub(/\.log/,'').sub(/@/,'.').to_f}.each do |log_file_name|
      log_file_path=File.join(repo_path,log_file_name)
      mavenOrGradle(log_file_path)
    end
    puts "Projects #{repo_path} has #{@count_one_project} compiler error files"
    @count_projects+=1 if @count_one_project>0
    puts "There are #{@count_projects} projects have compiler"
  end
end

@build_logs_path='../build_logs/'
traverseDir(@build_logs_path)
puts "There are #{@count} bad files in total."