/*=======
 Query 1:
=========*/

SELECT
*

FROM
customer

ORDER BY
customer_id ASC;

/*=======
 Query 2:
=========*/

SELECT
(last_name || ', ' || first_name) AS "Name"

FROM
actor

ORDER BY
last_name ASC, first_name ASC;

/*=======
 Query 3:
=========

WHERE
	title ILIKE '%love%'

Though it's tempting to use a clause like the one above, this would include 
instances where 'love' is a substring of a larger string; a title like "The 
Gloves Are Off" would be returned. The prompt seems to imply that we want 
to match the whole word only. Hence, we have the solution below (using a 
regular expression):
*/

SELECT
title

FROM
film

WHERE
title ~* '\mlove\M'

ORDER BY
title ASC;

/*=======
 Query 4:
=========*/

SELECT
title, length,
CASE
	WHEN (length < 50) THEN 'Short Movie'
	WHEN (length BETWEEN 50 AND 180) THEN 'Standard'
	WHEN (length > 180) THEN 'Extended Cut'
	ELSE 'Error'
END AS "Length"

FROM
film

ORDER BY
length ASC;

/*=======
 Query 5:
=========*/

SELECT
first_name, last_name

FROM
customer

WHERE
first_name ILIKE 'Carl' OR first_name ILIKE 'Anna';

/*=======
 Query 6:
=========*/

SELECT
rental_id, (return_date - rental_date) AS "Duration"

FROM
rental

ORDER BY
"Duration" DESC NULLS FIRST;

/*=======
 Query 7:
=========*/

SELECT
*

FROM
rental

WHERE
return_date ISNULL

ORDER BY
rental_id ASC;

/*=======
 Query 8:
=========*/

SELECT
country

FROM
country

WHERE
country ILIKE '%ta%'

ORDER BY
country ASC;

/*=======
 Query 9:
=========*/

SELECT
*

FROM
rental

WHERE
rental_date BETWEEN '2005-05-01' AND '2005-08-03'

ORDER BY
rental_date ASC;

/*========
 Query 10:
==========

What is a word? 

We can define words as sequences of characters that are separated by whitespace. 
Their length is variable. A simple way to describe the number of words that exist 
in a string is the number of spaces that it has plus 1. 

For example, "This is a test string" has 4 spaces + 1 = 5 words. If we take the 
total length of the description MINUS the total length of the description without 
spaces (which we get courtesy of REPLACE), the difference will be the total number 
of spaces:

(LENGTH(description) - LENGTH(REPLACE(description, ' ', '')) + 1

However, one major drawback to this approach is the assumption that one space exists 
between each word. Consecutive spaces will inflate the number of spaces (and, thus, 
our word count) without more words actually existing. 

ARRAY_LENGTH(REGEXP_SPLIT_TO_ARRAY(BTRIM(description),'(\s+)'), 1)

To counter this, we can try the method above, which utilizes a combination of BTRIM, 
REGEXP_SPLIT_TO_ARRAY, and ARRAY_LENGTH. First, BTRIM is used to trim any potential 
whitespace on both sides (leading and trailing) from the description. Next, a regular 
expression delimits this result and produces an array (\s matches any whitespace 
character; + matches the previous token between 1 and unlimited, as many times as 
possible. So, in this case, any number of consecutive whitespace characters acts our 
delimiter). Finally, we return the array's length as the word count.
*/

SELECT
title, description, ARRAY_LENGTH(REGEXP_SPLIT_TO_ARRAY(BTRIM(description),'(\s+)'), 1) AS "Word Count"

FROM
film

WHERE
ARRAY_LENGTH(REGEXP_SPLIT_TO_ARRAY(BTRIM(description),'(\s+)'), 1) > 18

ORDER BY
"Word Count";