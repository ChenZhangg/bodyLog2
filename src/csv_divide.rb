require 'csv'
def csv_traverse(csv_file)
  row_number=0
  CSV.foreach(csv_file,headers:true,col_sep:',') do |row|
    row_number+=1
  end
  row_count=0
  CSV.foreach(csv_file,headers:true,col_sep:',') do |row|
    row_count+=1
    if row_count<=row_number/10
      i=0
    elsif row_count<=row_number*2/10
      i=1
    elsif row_count<=row_number*3/10
      i=2
    elsif row_count<=row_number*4/10
      i=3
	  elsif row_count<=row_number*5/10
      i=4
    elsif row_count<=row_number*6/10
      i=5
    elsif row_count<=row_number*7/10
      i=6
    elsif row_count<=row_number*8/10
      i=7
    elsif row_count<=row_number*9/10
      i=8
    else
      i=9
    end
    File.open("repo#{i}.csv",'a+') do |file|
      CSV(file,col_sep:',') do |csv|
        csv<<[row[0],row[1],row[2]]
      end
    end
  end
end
csv_traverse('repoAbove1000WithTravis.csv')
