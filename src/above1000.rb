require 'csv'
def csv_traverse(csv_file)
  CSV.foreach(csv_file,headers:false,col_sep:',') do |row|
    File.open("repoAbove1000WithTravisAbove1000.csv",'a+') do |file|
      CSV(file,col_sep:',') do |csv|
        csv<<[row[0],row[1],row[2]] if row[2].to_i>=1000
      end
    end
  end
end
csv_traverse('repoAbove1000WithTravis.csv')