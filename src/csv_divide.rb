require 'csv'
def csv_traverse(csv_file)
  row_number=0
  CSV.foreach(csv_file,headers:true,col_sep:',') do |row|
    row_number+=1
  end
  row_count=0
  CSV.foreach(csv_file,headers:true,col_sep:',') do |row|
    row_count+=1
    if row_count<=row_number/5
      i=0
    elsif row_count<=row_number*2/5
      i=1
    elsif row_count<=row_number*3/5
      i=2
    elsif row_count<=row_number*4/5
      i=3
    else
      i=4
    end
    File.open("repo#{i}.csv",'a+') do |file|
      CSV(file,col_sep:',') do |csv|
        csv<<[row[0],row[1],row[2]]
      end
    end
  end
end
csv_traverse('repoAbove1000WithTravis.csv')
