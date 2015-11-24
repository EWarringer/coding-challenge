require "pg"
require "csv"

def db_connection
  begin
    connection = PG.connect(dbname: "erik_warringer_tenizen_challenge")
    yield(connection)
  ensure
    connection.close
  end
end

# import csv file and set it to variable 'csv_list'
apartments = CSV.readlines('apartments.csv', headers: true, header_converters: :symbol)

db_connection do |conn|
  # populate database by looping through each apartment
  apartments.each do |row|

    conn.exec_params('
    INSERT INTO apartments (latitude, longitude, bedrooms, bathrooms, square_footage, price, amenities)
    VALUES ($1, $2, $3, $4, $5, $6, $7)',
    [row[:latitude], row[:longitude], row[:bedrooms], row[:bathrooms], row[:square_footage], row[:price], row[:amenities]]
    )
  end
end
