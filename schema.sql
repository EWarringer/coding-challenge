CREATE TABLE apartments(
  id SERIAL PRIMARY KEY,
  latitude double precision,
  longitude double precision,
  bedrooms integer,
  bathrooms integer,
  square_footage integer,
  price integer,
  amenities varchar(250)
);
