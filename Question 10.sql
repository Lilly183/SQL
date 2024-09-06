/*=======
 Query 1:
=========*/

SELECT
*

FROM
actor

ORDER BY
actor_id ASC;

/*=======
 Query 2:
=========*/

SELECT
last_name || ', ' || first_name AS "Full Name"

FROM
actor

ORDER BY
last_name ASC, first_name ASC;

/*=======
 Query 3:
=========*/

SELECT
film_id, title, first_name, last_name

FROM
film INNER JOIN film_actor USING (film_id) INNER JOIN actor USING (actor_id)

WHERE
first_name ILIKE 'Zero' AND last_name ILIKE 'Cage'

ORDER BY
film_id ASC;

/*=======
 Query 4:
=========*/

SELECT
last_name, first_name, address, city, country

FROM
customer INNER JOIN address USING (address_id) 
	INNER JOIN city USING (city_id) 
		INNER JOIN country USING (country_id)

WHERE
country ILIKE 'Italy';

/*=======
 Query 5:
=========*/

SELECT
name, COUNT(*)

FROM
film INNER JOIN film_category USING (film_id) INNER JOIN category USING (category_id) 

GROUP BY
category_id

ORDER BY
name ASC;

/*=======
 Query 6:
=========*/

SELECT
customer_id, last_name, first_name, ROUND(SUM(amount), 2) AS "Total Spent"

FROM
payment INNER JOIN customer USING (customer_id)

GROUP BY
customer_id

ORDER BY
last_name ASC, first_name ASC;

/*=======
 Query 7:
=========*/

SELECT
actor_id, last_name, first_name, COUNT(*) AS "Films Starred"

FROM
film INNER JOIN film_actor USING (film_id) INNER JOIN actor USING (actor_id)

GROUP BY
actor_id

HAVING
COUNT(*) >= 35

ORDER BY
last_name ASC, first_name ASC;

/*=======
 Query 8:
=========*/

SELECT
customer_id, last_name, first_name, COUNT(*) AS "Rental Count"

FROM
rental INNER JOIN customer USING (customer_id)

GROUP BY
customer_id

ORDER BY
"Rental Count" DESC

-- LIMIT 1
;