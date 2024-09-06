--=========================
-- Get Owner of a Database:
--=========================

SELECT 
d.datname AS "Name", pg_catalog.pg_get_userbyid(d.datdba) AS "Owner"

FROM 
pg_catalog.pg_database d

WHERE 
d.datname = 'BigCompany'

ORDER BY 1;

--=====================
-- Get Owner of Tables:
--=====================

SELECT 
* 

FROM 
pg_tables

ORDER BY
schemaname ASC, tablename ASC;

--======================================
-- See All Tables With a Specific Owner:
--======================================

SELECT 
* 

FROM
pg_tables 

WHERE 
tableowner = 'BigBoss';