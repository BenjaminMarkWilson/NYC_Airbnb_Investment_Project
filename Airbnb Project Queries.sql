-- Data cleaning for Host Table

--Check for NULL values
--NULL values exist in host_name, but unique identifier (host_id) already exists: No action required
SELECT *
FROM PortfolioProject..[NY Airbnb Hosts]
WHERE property_id IS NULL OR host_id IS NULL OR host_name IS NULL

--Check for 'blanks'
SELECT *
FROM PortfolioProject..[NY Airbnb Hosts]
WHERE len(property_id) = 0 OR len(host_id) = 0 OR len(host_name) = 0

--Comparing value counts with DISTINCT value counts reveals that some property ids, host ids, and host names appear more than once
SELECT COUNT(property_id) as property_id_count, COUNT(host_id) as host_id_count, COUNT(host_name) as host_name_count
FROM PortfolioProject..[NY Airbnb Hosts]
	
SELECT COUNT(DISTINCT property_id) as unique_properties, COUNT(DISTINCT host_id) as unique_host_ids, COUNT(DISTINCT host_name) as unique_host_names
FROM PortfolioProject..[NY Airbnb Hosts]

--Assigning RANK() to each combination of property_id, host_id and host_name checks for true duplicates
WITH CTE as (
	SELECT property_id, host_id, host_name, RN = ROW_NUMBER() OVER(PARTITION BY property_id, host_id, host_name ORDER BY property_id, host_id, host_name)
	FROM PortfolioProject..[NY Airbnb Hosts])
SELECT *
FROM CTE
WHERE RN > 1

--Duplicates of all values exist, these should be removed
WITH CTE as (
	SELECT property_id, host_id, host_name, RN = ROW_NUMBER() OVER(PARTITION BY property_id, host_id, host_name ORDER BY property_id, host_id, host_name)
	FROM PortfolioProject..[NY Airbnb Hosts])
DELETE FROM CTE WHERE RN >1

----Data cleaning for Properties Table

--Check for NULL values
--While there might be a more efficient way to REMOVE all rows with null values (joining the two tables and removing nulls), not all nulls need to be removed. Each column should be checked individually and addressed.
--13 nulls in 'name'
--Lot of nulls in 'reviews_per_month'
--Lots of nulls in 'availability_365'
--None of these need to be removed: other unique identifiers can be used instead of 'name'; 'reviews_per_month' can be set to zero; 'availability_365 can be left as NULL'

--Address NULL values
UPDATE PortfolioProject..[NY Airbnb Properties]
SET reviews_per_month = 0
WHERE reviews_per_month IS NULL

--Check for 'blank' values
SELECT *
FROM PortfolioProject..[NY Airbnb Properties]
WHERE len(id) = 0; repeat for all columns
--No 'blank' values

--Check for invalid values
--Only invalid values I can think of would be for: 1. Neighbourhood_group (we don't have a list of all neighbourhoods), 2. Room_type, and 3. Price
SELECT * 
FROM PortfolioProject..[NY Airbnb Properties]
WHERE neighbourhood_group NOT IN ('Queens', 'Brooklyn', 'Manhattan', 'Staten Island', 'Bronx')
 
SELECT *
FROM PortfolioProject..[NY Airbnb Properties]
WHERE room_type NOT IN ('Private room', 'Entire home/apt', 'Shared room', 'Hotel room')

SELECT *
FROM PortfolioProject..[NY Airbnb Properties]
WHERE price = 0

--The only invalid values are in the price column; several are listed with a price of $0, all of which are 'Hotel rooms'. This should be changed to some numeric value (as opposed to choosing NULL or removing the row)
--Zeros should be replaced with the average price, which should be calculated after the zeros are already removed (so as not to influence the calculation)
WITH CTE as (
	SELECT NULLIF(price, 0) as price, id, room_type
	FROM PortfolioProject..[NY Airbnb Properties])
SELECT ROUND(AVG(price), 2) as avg_hotel_price
FROM CTE

--This yeilds the avg_hotel_price of $200.25, and this can be updated using the following query:
UPDATE PortfolioProject..[NY Airbnb Properties]
SET price = 200.25
WHERE price = 0 

--Check for 'true' duplicates
WITH CTE as(
	SELECT *, RN = ROW_NUMBER() OVER(PARTITION BY id, name, host_id, neighbourhood_group, neighbourhood, latitude, longitude, room_type, price, minimum_nights, number_of_reviews, reviews_per_month, availability_365)
	FROM PortfolioProject..[NY Airbnb Properties])
SELECT *
FROM CTE
WHERE RN > 1

--Some exact duplicates exist, these should be removed
WITH CTE as(
	SELECT *, RN = ROW_NUMBER() OVER(PARTITION BY id, name, host_id, neighbourhood_group, neighbourhood, latitude, longitude, room_type, price, minimum_nights, number_of_reviews, reviews_per_month, availability_365)
	FROM PortfolioProject..[NY Airbnb Properties])
DELETE FROM CTE WHERE RN > 1

--ANALYSIS
--1.Which neighborhood group has the most properties?
SELECT neighbourhood_group, number_of_properties = COUNT(DISTINCT(id))
FROM PortfolioProject..[NY Airbnb Projects]

--2. Which neighborhood group has the highest average price?
SELECT neighbourhood_group, avg_price = ROUND(AVG(price), 2)
FROM PortfolioProject..[NY Airbnb Properties]
GROUP BY neighbourhood_group

--3. What does the breakdown of property types look like within neighborhood groups?
SELECT neighbourhood_group, room_type, num_properties = COUNT(DISTINCT(id))
FROM PortfolioProject..[NY Airbnb Properties]
GROUP BY neighbourhood_group, room_type
ORDER BY neighbourhood_group, num_properties DESC

--4. What is the most expensive room type (on average) within each neighborhood group?
SELECT neighbourhood_group, room_type, avg_price = ROUND(AVG(price), 2)
FROM PortfolioProject..[NY Airbnb Properties]
GROUP BY neighbourhood_group, room_type
ORDER BY neighbourhood_group, avg_price DESC

--5. What does the pricing spread look like within each neighborhood group?
SELECT neighbourhood_group, max_price = MAX(price), lowest_price = MIN(price), avg_price =  ROUND(AVG(price),2)
FROM PortfolioProject..[NY Airbnb Properties]
GROUP BY neighbourhood_group
ORDER BY avg_price DESC

--6. What room type is the most common within each neighborhood group?
WITH CTE as (
	SELECT neighbourhood_group, room_type, num_properties = COUNT(room_type), rn = ROW_NUMBER() OVER(PARTITION BY neighbourhood_group ORDER BY COUNT(room_type) DESC)
	FROM PortfolioProject..[NY Airbnb Properties]
GROUP BY neighbourhood_group, room_type)
SELECT neighbourhood_group, room_type, num_properties
FROM CTE
WHERE rn = 1

--7. Which neighborhood group has the most properties which are either private rooms or entire homes/apts?
SELECT neighbourhood_group, room_type, num_properties = COUNT(room_type)
FROM PortfolioProject..[NY Airbnb Properties]
WHERE room_type = 'Private room' or room_type = 'Entire home/apt'
GROUP BY neighbourood_group, room_type
ORDER BY neighbourhood_group, room_type

--8. Within each neighborhood group, which room type receives the most reviews?
WITH CTE as (
	SELECT neighbourhood_group, room_type, reviews = SUM(number_of_reviews), rn = ROW_NUMBER() OVER (PARTITION BY neighbourhood_group ORDER BY SUM(number_of_reviews) DESC)
	FROM PortfolioProject..[NY Airbnb Properties]
GROUP BY neighbourhood_group, room_type)
SELECT *
FROM CTE
WHERE rn = 1
 
--9. What are the most common 'minimum night' requirements found throughout NYC?
SELECT DISTINCT(minimum_nights), num_properties = COUNT(minimum_nights)
PortfolioProject..[NY Airbnb Properties]
GROUP BY minimum_nights
ORDER BY num_poperties DESC

--10. For each room type, what are the 3 most common 'minimum night' requirements?
WITH CTE as (
	SELECT DISTINCT(minimum_nights), num_properties = COUNT(minimum_nights), room_type, rn = ROW_NUMBER() OVER(PARTITION BY room_type ORDER BY room_type, COUNT(minimum_nights) DESC)
	FROM PortfolioProject..[NY Airbnb Properties]
	GROUP BY room_type, minimum_nights)
SELECT room_type, minimum_nights, num_properties, rn
FROM CTE
WHERE rn in (1,2,3)

