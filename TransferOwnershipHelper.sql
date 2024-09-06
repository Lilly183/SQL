/*
=======
Tables:
=======
*/

SELECT 
'ALTER TABLE '|| schemaname || '."' || tablename ||'" OWNER TO "BigBoss";' AS "SQL Statements"

FROM 
pg_tables 

WHERE 
NOT schemaname IN ('pg_catalog', 'information_schema')

ORDER BY 
schemaname, tablename;

/* 
==========
Sequences:
==========
*/

SELECT 
'ALTER SEQUENCE '|| sequence_schema || '."' || sequence_name ||'" OWNER TO "BigBoss";' AS "SQL Statements"

FROM 
information_schema.sequences 

WHERE 
NOT sequence_schema IN ('pg_catalog', 'information_schema')

ORDER BY 
sequence_schema, sequence_name;

/*
======
Views:
======
*/

SELECT 
'ALTER VIEW '|| table_schema || '."' || table_name ||'" OWNER TO "BigBoss";' AS "SQL Statements"

FROM
information_schema.views 

WHERE 
NOT table_schema IN ('pg_catalog', 'information_schema')

ORDER BY 
table_schema, table_name;

/*
===================
Materialized Views:
===================
*/

SELECT 
'ALTER TABLE '|| oid::regclass::text ||' OWNER TO "BigBoss";' AS "SQL Statements"

FROM 
pg_class 

WHERE 
relkind = 'm'

ORDER BY 
oid;