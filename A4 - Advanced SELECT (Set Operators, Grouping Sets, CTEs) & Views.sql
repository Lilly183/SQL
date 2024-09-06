/*=======
 Query 1:
=========*/

SELECT
rating, COUNT(*) AS "Film Count"

FROM
film

GROUP BY
rating

HAVING
COUNT(*) >= 200

ORDER BY
rating ASC;

/*=======
 Query 2:
=========*/

/*
For the inner query in the FROM clause, we might be tempted to use something like this:

SELECT
*

FROM
payment

WHERE
amount >= 9.00

Essentially, we restrict the payment table to only those of an amount >= $9.00, group on the 
basis of customer_id, count the number of records per group, and restrict those groups to only 
those having COUNT(*) >= 3.

Whilst this gives us the same output as what we're about to do instead, we still probably 
shouldn't follow this approach. The reason why is this: What if a customer decides to split 
their payment towards the same rental over multiple payments? 

Imagine if a customer makes two payments for the same rental, each of which is greater than 
$9.00. If we use the method above, we would be counting both of these payments in the outer 
query. Alternatively, imagine what happens if each of the customer's payments are SEPARATELY 
below $9.00, but, for the entire rental, they add up to be >= $9.00. The WHERE clause would 
have eliminated them from even being considered.

The question asks us to provide the name of the customers that have performed at least 3 rentals 
that were at least $9.00 each. Therefore, this is what our revised inner query says: group by 
customer_id, then rental_id. Then, for each of these logical blocks, calculate the sum. Finally, 
return only the logical blocks whose total is >= $9.00.
*/

SELECT
customer_id, last_name, first_name, COUNT(*) AS "Number of Rentals >= $9.00"

FROM
customer INNER JOIN (SELECT
					customer_id, rental_id, SUM(amount)

					FROM
					payment

					GROUP BY
					customer_id, rental_id

					HAVING
					SUM(amount) >= 9.00) AS "Temp" USING (customer_id)

GROUP BY
customer_id

HAVING
COUNT(*) >= 3

ORDER BY
last_name ASC, first_name ASC;

/*=======
 Query 3:
=========*/

/*
EXCEPT requires that all inputs have the same number of columns and that they are of 
compatible types. All we're doing here is selecting all of the customers in the customer 
table (customer.customer_id) EXCEPT those in the rental table (rental.customer_id), then 
joining this result with the customer table to get the other fields (i.e., customer_id, 
first_name, last_name). Apparently, there are no customers that have never performed a 
rental.
*/

SELECT
customer_id, last_name, first_name

FROM
customer INNER JOIN (SELECT
					customer_id

					FROM
					customer

					EXCEPT

					SELECT
					customer_id

					FROM
					rental) AS "CustomersWithNoRentals" USING (customer_id)

ORDER BY
last_name ASC, first_name ASC;

/*=======
 Query 4:
=========*/

SELECT
COUNT(*), name, rating

FROM
film INNER JOIN film_category USING (film_id) 
	INNER JOIN category USING (category_id)

GROUP BY
	-- ROLLUP (name, rating)
	GROUPING SETS
	(
		(name, rating),
		(name),
		()
	)

ORDER BY
name ASC NULLS LAST, rating NULLS LAST;

/*=======
 Query 5:
=========*/

SELECT
customer_id, last_name, first_name

FROM
customer AS "c"

WHERE EXISTS
	(SELECT
	1

	FROM
	rental AS "r"

	WHERE r.customer_id = c.customer_id)

ORDER BY
last_name ASC, first_name ASC;

/*=======
 Query 6:
=========*/

WITH MaxRentalRatePerCategory AS (SELECT
								  category_id, MAX(rental_rate) AS "Category Max Rental Rate"
								  
								  FROM
								  film INNER JOIN film_category USING (film_id) 
									  INNER JOIN category USING (category_id)
								  
								  GROUP BY
								  category_id)

SELECT
category_id, name AS "Film Category", film_id, title, rental_rate, "Category Max Rental Rate"

FROM
film INNER JOIN film_category USING (film_id) 
	INNER JOIN category USING (category_id) 
		INNER JOIN MaxRentalRatePerCategory USING (category_id)

WHERE
rental_rate = "Category Max Rental Rate"

ORDER BY
"Film Category" ASC, title ASC;

/*=======
 Query 7:
=========*/

WITH AvgLengthPerCategory AS (SELECT
							  category_id, ROUND(AVG(length), 0) AS "Category Average Length"
							  
							  FROM
							  film INNER JOIN film_category USING (film_id) 
								  INNER JOIN category USING (category_id)
							  
							  GROUP BY
							  category_id)

SELECT
category_id, name AS "Film Category", film_id, title, length, "Category Average Length"

FROM
film INNER JOIN film_category USING (film_id) 
	INNER JOIN category USING (category_id) 
		INNER JOIN AvgLengthPerCategory USING (category_id)

WHERE
length = "Category Average Length"

ORDER BY
"Film Category" ASC, title ASC;

/*=======
 Query 8:
=========*/

CREATE OR REPLACE VIEW view_movie_language AS (SELECT
											   film_id, title, length, language_id, name
											   
											   FROM
											   film INNER JOIN language USING (language_id)
											   
											   ORDER BY
											   title ASC);

/*=======
 Query 9:
=========*/

CREATE MATERIALIZED VIEW IF NOT EXISTS view_last_rental AS (WITH LatestRentalByCustomer AS (SELECT
																							DISTINCT ON (customer_id) *

																							FROM
																							rental

																							ORDER BY
																							customer_id ASC, rental_date DESC)

															SELECT
															customer_id, last_name, first_name, rental_date AS "Most Recent Rental"

															FROM
															customer INNER JOIN LatestRentalByCustomer USING (customer_id)

															ORDER BY
															last_name ASC, first_name ASC) WITH DATA;