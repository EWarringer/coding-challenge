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

# 1) What is the average square footage of all one-bedroom apartments, rounded to the nearest square foot?
def question_1
  # set a variable to an empty array
  array_of_square_footages = []

  # connect to db whenever a db query needs to be made
  db_connection do |conn|
    # create array of square footage stats from all one bedroom apts in DB and set to variable square_footages
    square_footages = conn.exec("SELECT square_footage FROM apartments WHERE bedrooms = 1")
    # loop through each hash in square_footages, and push the number itself (in float form) to empty array array_of_square_footages
    square_footages.each do |row|
      array_of_square_footages << row["square_footage"].to_f
    end
  end
  # the total square footage is equal to the sum of the newly populated array_of_square_footages
  total_area = array_of_square_footages.inject(:+)
  # the average area is the total area divided by the number of areas we added together
  average_area = total_area/array_of_square_footages.count # 195834sqft divided by 209 apartments = 937.0047846889952
  # change average_area to integer instead of float
  average_area = average_area.to_i # 937sqft

  # return answer
  puts "\n1) The average square footage of all one-bedroom apartments is #{average_area}sqft"
end


# 2) What is the closest studio apartment to 210 Broadway, Cambridge, MA (straight-line distance, not walking/driving)?
#    Your answer should include the distance in miles, rounded to two decimal places.
def question_2
  # the latitude and longitude of 210 Broadway is 42.365869, -71.093471

  # create empty array to eventually hold the distances in miles of all 1 bedroom apartments
  array_of_distances = []

  db_connection do |conn|
    # create array of location stats from all studio (0 bedroom) apts in the DB and set to variable name locations
    locations = conn.exec("SELECT latitude, longitude FROM apartments WHERE bedrooms = 0")
    # loop through each location and use haversine formula to find the distance in kilometers
    # between 210 broadway and each 0 bedroom apartment.
    include Math
    locations.each do |row|
      lat1 = 42.365869 * PI / 180
      lon1 = -71.093471 * PI / 180
      lat2 = row["latitude"].to_f * PI / 180
      lon2 = row["longitude"].to_f * PI / 180
      kilometers = 12742 * asin(sqrt(sin((lat2-lat1)/2)**2 + cos(lat1) * cos(lat2) * sin((lon2 - lon1)/2)**2))
      # convert kilometers to miles and push the number (as a float) to the empty array, array_of_distances
      miles = (kilometers * 0.62137)
      array_of_distances << miles
    end
  end
  # find the apartment with the smallest/min distance, round it 2 decimal places,
  # and set to variable closest_apartment
  closest_apartment = '%.2f' % array_of_distances.min

  puts "\n2) The closest studio apartment to 210 Broadway, Cambridge, MA, is #{closest_apartment} mi away"
end



# this calculator returns a hash of every amenity along with the average value
# that it contributes per square foot. This method is used in future problems.

def amenity_calculator_method
  amenity_list = {}
  db_connection do |conn|

    apartments = conn.exec("SELECT id, price, square_footage, amenities FROM apartments")
    # loop through each apartment
    apartments.each do |apartment|
      # split amenities for turn them into an array
      amenities_array = apartment["amenities"].split('|')
      # loop through each amenity in each apartment
      amenities_array.each do |amenity|
        # if the amenity is already in the hash amenity_list then skip this, otherwise proceed
        unless amenity_list.include?(amenity)
          # set two empty arrays.
          # one for all the prices per square foot of apartments with the given aminety
          # the other for all the prices of apartments who don't have that amenity
          all_sqft_prices_with_amenity = []
          all_sqft_prices_without_amenity = []

          with_amenity = conn.exec("SELECT price, square_footage, amenities FROM apartments WHERE amenities LIKE '%#{amenity}%'")
          without_amenity = conn.exec("SELECT price, square_footage, amenities FROM apartments WHERE amenities NOT LIKE '%#{amenity}%'")

          # take arrays of the separated rows, loop through each,
          # take the price divided by square feet and push results to respective empty arrays above
          with_amenity.each do |row|
            price_per_sqft = row["price"].to_f/row["square_footage"].to_f
            all_sqft_prices_with_amenity << price_per_sqft
          end
          without_amenity.each do |row|
            price_per_sqft = row["price"].to_f/row["square_footage"].to_f
            all_sqft_prices_without_amenity << price_per_sqft
          end

          # find the average price per square foot of apartments with and without the given amenity
          avg_sqft_price_with_amenity = all_sqft_prices_with_amenity.inject(:+)/all_sqft_prices_with_amenity.count
          avg_sqft_price_without_amenity = all_sqft_prices_without_amenity.inject(:+)/all_sqft_prices_without_amenity.count

          # subtract the avg price with the amenity from the avg price without it
          amenity_sqft_house_value = avg_sqft_price_with_amenity - avg_sqft_price_without_amenity

          # push the name of the amenity along with the result in hash form to "amenity_list" (top of method)
          amenity_list[amenity] = amenity_sqft_house_value
        end
      end
    end
  end
  # return the list when calling the method
  amenity_list
end



# 3) What would you suggest as the price for a 1100 square feet, two-bedroom, one-bath apartment with off-street parking and a secure entrance at 210 Broadway in Cambridge, based on comparable listings? Round your answer to the nearest $50.
def question_3
  # set the amenity list created to variable amenity_value_calculator
  amenity_value_calculator = amenity_calculator_method

  # set empty array for nearby/close 2 bedroom, 1 bath apartments
  close_apartment = []

  db_connection do |conn|
    # similar to the math used before to find local apartments except this time
    # it is searching only for apartments with 2 bedrooms and 1 bath for easier comparison
    locations = conn.exec(
    "SELECT latitude, longitude, square_footage, price, amenities
    FROM apartments WHERE bedrooms = 2 AND bathrooms = 1
    ORDER BY square_footage ASC"
    )
    include Math
    locations.each do |row|
      lat1 = 42.365869 * PI / 180
      lon1 = -71.093471 * PI / 180
      lat2 = row["latitude"].to_f * PI / 180
      lon2 = row["longitude"].to_f * PI / 180
      kilometers = 12742 * asin(sqrt(sin((lat2-lat1)/2)**2 + cos(lat1) * cos(lat2) * sin((lon2 - lon1)/2)**2))
      miles = (kilometers * 0.62137)
      #only add apartments to array that are within 1 mile of 210 Broadway
      if miles < 1
        close_apartment << row
      end
    end
  end

  # now with the list of local apartments, I want to find the
  # "average priceper square foot per LOCAL apartment WITHOUT amenities" so I can determine
  # how much to charge for the apartment in the question
  #
  #set empty array for future array of prices of these apartments without amenities
  local_sqft_values_without_amenities = []

  # loop through each local apartment
  close_apartment.each do |apartment|
    # find the value of the apartment WITH amenities
    apt_sqft_value = apartment["price"].to_f/apartment["square_footage"].to_f
    amenities_array = apartment["amenities"].split('|')
    # loop through each amenity for each apartment, and using the amenity_value_calculator,
    # tallying the total value of amenities in the apartment.
    amenities_sqft_value = 0
    amenities_array.each do |amenity|
      amenities_sqft_value += amenity_value_calculator[amenity]
    end
    # subtract amenity values from apartments and push values to empty array
    local_sqft_values_without_amenities << apt_sqft_value - amenities_sqft_value
  end
  # find average price per sqft of local apartments
  avg_local_sqft_price_without_amenities = local_sqft_values_without_amenities.inject(:+)/local_sqft_values_without_amenities.count

  # take the amount of the average 2 bedroom 1 bath apartment (per sqft)
  # add the sqft value of each amenity in the question
  value_per_sqft = avg_local_sqft_price_without_amenities + amenity_value_calculator["Off-Street Parking"] + amenity_value_calculator["Secure Entrance"]

  # multiply this by 1100sqft
  value = (value_per_sqft * 1100).to_i

  # round to the nearest $50
  if value % 50 < 25
    value -= (value % 50)
  else
    value += (50 - (value % 50))
  end

  puts "\n3) For this apartment, I would suggest a price of #{value}\n\n"
end




# 4) What are the top 3 “best value” studio apartments in the area, and why?
def question_4
  # set amenity calculator method to variable
  amenity_value_calculator = amenity_calculator_method
  # set empty array
  local_apartment = []

  db_connection do |conn|
    # create variable called "locations" equal to all the apartments with 0 bedrooms
    locations = conn.exec("SELECT * from apartments WHERE bedrooms = 0")

    # same equation as before
    include Math
    locations.each do |row|
      lat1 = 42.365869 * PI / 180
      lon1 = -71.093471 * PI / 180
      lat2 = row["latitude"].to_f * PI / 180
      lon2 = row["longitude"].to_f * PI / 180
      kilometers = 12742 * asin(sqrt(sin((lat2-lat1)/2)**2 + cos(lat1) * cos(lat2) * sin((lon2 - lon1)/2)**2))
      miles = (kilometers * 0.62137)
      if miles < 1
        local_apartment << row
      end
    end
  end

  #same as before, only with apartments that have 0 bedrooms
  local_sqft_values_without_amenities = []

  local_apartment.each do |apartment|
    apt_sqft_value = apartment["price"].to_f/apartment["square_footage"].to_f
    amenities_array = apartment["amenities"].split('|')
    amenities_sqft_value = 0
    amenities_array.each do |amenity|
      amenities_sqft_value += amenity_value_calculator[amenity]
    end
    local_sqft_values_without_amenities << apt_sqft_value - amenities_sqft_value
  end
  avg_local_sqft_price_without_amenities = local_sqft_values_without_amenities.inject(:+)/local_sqft_values_without_amenities.count

  # empty hash to hold the amound of savings per local apartment along with the id of the apartment to identify it
  apartment_deal = {}

  # loop through each apartment and calculate the average amount the apartment should cost per square foot without amenities
  # then add the average value those amenities contribute to get the expected market price for the apartment.
  # subtract the actual price of the apartment from this and you have the "deal" on the apartment
  local_apartment.each do |apartment|
    amenities_array = apartment["amenities"].split('|')
    amenities_value = 0
    amenities_array.each do |amenity|
      amenities_value += amenity_value_calculator[amenity]
    end
    avg_value = apartment["square_footage"].to_f * (avg_local_sqft_price_without_amenities + amenities_value)
    apartment_deal[apartment["id"]] = avg_value - apartment["price"].to_f
  end

  # order these by the amount saved and take the largest 3 differenced to get the 3 best deals
  ordered_savings = apartment_deal.sort_by {|_key, value| value}
  top_three = ordered_savings[-3..-1]
  puts "4) Apartment IDs & cash amount of each deal"
  puts top_three
  puts "The top three best-value apartments in the area are: Apartment ID 197 with $597.98 savings, followed by apartments 753 and 492."
  puts "This is found by taking the average price based on location, with average value of amenities,"
  puts "and subtracting the actual price of the apartment from it."
end



# 5) What is the approximate value of a pool? Round your answer to the nearest $10.
def question_5
  # two arrays, one for prices of houses with pools, and one for prices without pools
  with_pool = []
  without_pool = []

  db_connection do |conn|
    # query for these and push the results to their respective arrays
    with_amenity = conn.exec("SELECT price FROM apartments WHERE amenities LIKE '%Pool%'")
    without_amenity = conn.exec("SELECT price FROM apartments WHERE amenities NOT LIKE '%Pool%'")

    with_amenity.each do |row|
      with_pool << row["price"].to_f
    end
    without_amenity.each do |row|
      without_pool << row["price"].to_f
    end
  end

  # value = the average price with a pool minus the average price without a pool
  value = with_pool.inject(:+)/with_pool.count - without_pool.inject(:+)/without_pool.count

  # round the value to the nearest $10
  if value % 10 < 5
    value -= (value % 10)
  else
    value += (10 - (value % 10))
  end

  puts "\n5) The average value of a pool rounded to 10 dollars is $#{value}"
end

question_1
question_2
question_3
question_4
question_5
