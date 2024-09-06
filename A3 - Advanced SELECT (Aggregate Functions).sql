/*=======
 Query 1:
=========*/

-- SUBSTR works, too:
-- UPPER(SUBSTR(LTRIM(last_name), 1, 1)) AS "Surname First Character", COUNT(*) AS "Count"

SELECT
UPPER(LEFT(LTRIM(last_name), 1)) AS "Surname First Character", COUNT(*) AS "Count"

FROM
actor

GROUP BY
"Surname First Character"

ORDER BY
"Surname First Character" ASC;

/*=======
 Query 2:
=========*/

-- TO_CHAR works, too. We can use it to exercise more control over how the month is displayed (Just be mindful of how ORDER BY would be sorting strings):
-- TO_CHAR(rental_date, 'Month') AS "Month", COUNT(*) AS "Rental Count"

SELECT
EXTRACT(MONTH FROM rental_date) AS "Month", COUNT(*) AS "Rental Count"

FROM
rental

WHERE
EXTRACT(YEAR FROM rental_date) = 2005

GROUP BY
"Month"

ORDER BY
"Month" ASC;

/*=======
 Query 3:
=========*/

/*
It's tempting to use LEFT JOIN. What if a rental doesn't have a corresponding film_id? Of course, we'll see later that it must, but maybe we're worried about INNER JOIN excluding the results that we may already have for rentals where customer.first_name = 'Carl'. We may not know if the rental table's inventory_id field will be populated.

What we want most is the list of rentals for customers whose first name is exactly 'Carl'. We can't get that without the existence of common ground between the rental and customer tables (customer_id). If it were possible for the rental table's customer_id field to be blank, we couldn't say for certain whether or not someone with a first name = 'Carl' rented it. On the other hand, the customer table's customer_id field CAN'T be blank because it's the primary key. This must be an INNER JOIN.

Looking at the ERD, customer and inventory are both mandatory to rental. If we have a rental, we're going to have a customer. What is a customer if not customer_id? Likewise, if we have a rental, we're going to have inventory. What is inventory if not inventory_id? Therefore, for the rental table, we can rest assured that both the customer_id and inventory_id fields will be populated.

Similarly, film is mandatory to inventory. Altogether, if we have a rental, we can rest assured that it will have a customer and inventory - and by proxy of inventory, it will also have a film - so INNER JOIN between all of these should be fine.
*/

SELECT
rental_id, rental_date, title, customer_id, first_name, last_name

FROM
rental INNER JOIN customer USING (customer_id) 
	INNER JOIN inventory USING (inventory_id) 
		INNER JOIN film USING (film_id)

WHERE
first_name = 'Carl'

ORDER BY
rental_id ASC;

/*=======
 Query 4:
=========*/

SELECT
MIN(amount) AS "Minimum", MAX(amount) AS "Maximum", ROUND(AVG(amount), 2) AS "Average"

FROM
payment;

/*=======
 Query 5:
=========*/

/*
This is similar to Query 3. Keep in mind that we want the addresses COMPLETE with city and country information. City is mandatory to address, and country is mandatory to city. INNER JOIN is fine.
*/

SELECT
address_id, address, address2, city_id, city, district, postal_code, country_id, country

FROM
address INNER JOIN city USING (city_id) 
	INNER JOIN country USING (country_id)

ORDER BY
address_id ASC;

/*=======
 Query 6:
=========*/

SELECT
category_id, name, COUNT(film_id) AS "Film Count"

FROM
film INNER JOIN film_category USING (film_id) 
	INNER JOIN category USING (category_id)

GROUP BY
category_id

ORDER BY
category_id ASC;

/*=======
 Query 7:
=========*/

/*
postal_code is stored as a string, and, since we don't know whether any data validation techniques are being enforced, typos may be possible. Sanitization is probably a good idea. Unlike Query 1, we're dealing with a sequence of characters (length = 3), so we can't simply use TRIM. We need to throw out everything in postal_code that isn't a digit:

_23		=	23
1_3		=	13
12_		=	12
123		=	123

1_3		=	13
13_		=	13

To do this, we'll use REGEXP_REPLACE. Replace every character of postal_code that isn't a digit ('\D+') with nothing (''), then use LEFT to grab the first 3 characters of the result. DISTINCT returns only the unique values.

We also don't want to include any empty strings or NULL values (WHERE postal_code is different from ''). This prevents NULL values from being returned, since <> NULL is NULL, not true/false.

One final thing to consider: Because postal_code is a string, ORDER BY will sort the results lexicographically, not numerically (e.g., '3' falls between '299' and '300'). We could fix this, but, it's not really the focus of the question, so we'll leave it as-is.
*/

SELECT
DISTINCT(LEFT(REGEXP_REPLACE(postal_code, '\D+', ''), 3)) AS "District"

FROM
address

WHERE
postal_code <> ''

ORDER BY
"District" ASC;

/*=======
 Query 8:
=========*/

SELECT
store_id, SUM(amount) AS "Total Revenue"

FROM
payment INNER JOIN staff USING (staff_id) 
	INNER JOIN store USING (store_id)

GROUP BY
store_id

ORDER BY
store_id ASC;

/*=======
 Query 9:
=========*/

SELECT
customer_id, first_name, last_name, COUNT(customer_id) AS "Rental Count"

FROM
customer INNER JOIN rental USING (customer_id)

GROUP BY
customer_id

HAVING
COUNT(customer_id) > 40

ORDER BY
customer_id ASC;


/*========
 Query 10:
=========*/

/*
This one's deceptive. When retrieving film titles, we need to realize that, in order to gain access to the film table, we're coming from the rental table (rental --> inventory --> film). This is important because a single movie can be rented multiple times. If Duane Tubbs did this, the two separate occasions on which he rented the same movie should NOT appear as two different movies. We only want distinct films. 

We could use DISTINCT in the SELECT clause, like so:

DISTINCT(title), customer_id, first_name, last_name

This allows us to include fields from the customer table, allowing us to verify that all titles were indeed rented by Duane Tubbs. However, this approach is prone to failure if fields from the rental table are also included. Using GROUP BY is perhaps safer overall. As an added precaution, we should also GROUP BY film_id (not just the title), just in case two movies happen to share the same name.

For the WHERE clause, we have two options. We can either use the customer_id field, or we can use the first_name AND last_name fields. The former is a stronger identifier because it's the primary key. If we had multiple people named Duane Tubbs, this would allow us to select the right one. On the other hand, using first_name and last_name is more readable than customer_id.
*/

SELECT
film_id, title

FROM
rental INNER JOIN customer USING (customer_id) 
	INNER JOIN inventory USING (inventory_id) 
		INNER JOIN film USING (film_id)

WHERE
--customer_id = 513
first_name ILIKE 'Duane' AND last_name ILIKE 'Tubbs'

GROUP BY
film_id

ORDER BY
title ASC;