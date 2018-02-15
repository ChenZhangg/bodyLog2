require 'csv'
require 'mysql2'
require 'find'
def scanCSV(csv_file)
  File.foreach(csv_file) do |csv_line|
    begin
    row = CSV.parse(csv_line.gsub('\"', '""')).first
    rescue
      puts $!
      next
    end
    next if row[5].to_s != 'Java'
    puts "#{row[1]}                       #{row[5]}"
    File.open("test.csv",'a+') do |file|
      CSV(file,col_sep:',') do |csv|
        csv<<[row[1],row[1][29..-1]]
      end
    end
  end
end
Find.find('projects') do |f|
  if File.file?(f) && f=~/.*\/x.*/
    scanCSV(f)
  end
end
#csv_traverse('repoAbove1000WithTravis.csv')

#test('/home/zc/Downloads/xzaey')
#test('/home/zc/Downloads/projects.csv')
#r=SmarterCSV.process('/home/zc/Downloads/projects.csv',{:row_sep => :auto,:auto_row_sep_chars => 500,:chunk_size => 2,
#                      :headers_in_file => false,:user_provided_headers => [:id,:url,:owner_id,:name,:description,:language,:created_at,:forked_from,:deleted,:updated_at]})
#puts r
