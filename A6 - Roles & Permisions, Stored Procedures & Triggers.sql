-- Set search path so that "internal" schema is first:

SET 
search_path

TO
internal, public;

/* 
When the "BigCompany" database was created back in Assignment 5, its owner was declared as "postgres". Changing the owner of a database does not change the owner of its contents. For example, even if "BigCompany" is altered so that it belongs to "BigBoss" instead of "postgres", the "countries" table will still belong to "postgres". This is because, by default, a newly created object is owned by the role used to create it (https://serverfault.com/questions/198002/postgresql-what-does-grant-all-privileges-on-database-do).

This is problematic because, since at least V8.2, there IS a command (REASSIGN OWNED BY) in PostgreSQL that allows ownership of all objects in a database to be transferred from one role to another (https://stackoverflow.com/questions/1348126/postgresql-modify-owner-on-all-tables-simultaneously-in-postgresql). HOWEVER, it does NOT work if the role we're changing from is "postgres" because no distinction is made between "user defined and system objects" (Some objects are internal to postgres; their ownership cannot be changed). Thus, the following command won't work: 

REASSIGN OWNED BY "postgres" TO "BigBoss";

To better test the permissions of our upcoming roles, everything will be revoked from the "public" role, and we'll change the ownership for "BigCompany"'s contents using a series of SQL statements. These commands were generated from the queries of the attached companion document. They were derived from this post: https://stackoverflow.com/questions/1348126/postgresql-modify-owner-on-all-tables-simultaneously-in-postgresql#6624403

NOTE: Permissions for the default "public" schema have been ignored (Since everything is in the "internal" schema, it isn't particularly relevant for this assignment).
*/

/*
===============
"BigBoss" Role:
===============
*/

-- Instructions indicate that "BigBoss" is a USER ROLE, not a GROUP. This means that it should be capable of logging in; "BigBoss" must have a password.

CREATE ROLE "BigBoss" WITH LOGIN PASSWORD 'securePassword123';

/*
===========================
Database-Level Permissions:
===========================
*/

-- Grant "BigBoss" all database-level privileges (CREATE, CONNECT, and TEMPORARY).
GRANT ALL ON DATABASE "BigCompany" TO "BigBoss";

-- Change owner of the "BigCompany" database to "BigBoss"
ALTER DATABASE "BigCompany" OWNER TO "BigBoss";

-- Revoke all database-level privileges from "public".
REVOKE ALL ON DATABASE "BigCompany" FROM PUBLIC;

/*
Remember to connect to the "BigCompany" database before running any of the statements beyond this point!

=========================
Schema-Level Permissions:
=========================
*/

-- Grant all schema-level privileges for the "internal" schema to "BigBoss"
GRANT ALL ON SCHEMA internal TO "BigBoss";

-- Change owner of the "internal" schema to "BigBoss".
ALTER SCHEMA internal OWNER TO "BigBoss";

-- Revoke all schema-level privileges for the "internal" schema from "public"
REVOKE ALL ON SCHEMA internal FROM PUBLIC;

/*
========================
Table-Level Permissions:
========================
*/

-- Grant all table and sequence privileges in the "internal" schema to "BigBoss"
GRANT ALL ON ALL TABLES IN SCHEMA internal TO "BigBoss";
GRANT ALL ON ALL SEQUENCES IN SCHEMA internal TO "BigBoss";

-- Change owner of the tables in the "internal" schema to "BigBoss"
ALTER TABLE internal.countries OWNER TO "BigBoss";
ALTER TABLE internal.departments OWNER TO "BigBoss";
ALTER TABLE internal.employees OWNER TO "BigBoss";
ALTER TABLE internal.job_grades OWNER TO "BigBoss";
ALTER TABLE internal.job_history OWNER TO "BigBoss";
ALTER TABLE internal.jobs OWNER TO "BigBoss";
ALTER TABLE internal.locations OWNER TO "BigBoss";
ALTER TABLE internal.regions OWNER TO "BigBoss";

-- Change owner of the sequences in the "internal" schema to "BigBoss"
ALTER SEQUENCE internal.departments_department_id_seq OWNER TO "BigBoss";
ALTER SEQUENCE internal.employees_employee_id_seq OWNER TO "BigBoss";
ALTER SEQUENCE internal.locations_location_id_seq OWNER TO "BigBoss";
ALTER SEQUENCE internal.regions_region_id_seq OWNER TO "BigBoss";

-- Revoke all table and sequence privileges in the "internal" schema from "public"
REVOKE ALL ON ALL TABLES IN SCHEMA internal FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA internal FROM PUBLIC;

/*
=====================================
"BigEmployee" and "BigManager" Roles:
=====================================
*/

CREATE ROLE "BigEmployee";
CREATE ROLE "BigManager";

/*
===========================
Database-Level Permissions:
===========================
*/

GRANT CONNECT ON DATABASE "BigCompany" TO "BigEmployee", "BigManager";

/*
=========================
Schema-Level Permissions:
=========================
*/

GRANT USAGE ON SCHEMA internal TO "BigEmployee", "BigManager";

/*
========================
Table-Level Permissions:
========================
*/

GRANT SELECT ON 
	internal.countries,
	internal.departments,
	internal.employees,
	internal.job_grades, 
	internal.jobs,
	internal.locations,
	internal.regions 
TO "BigEmployee";

GRANT SELECT, INSERT, UPDATE, DELETE ON 
	internal.countries,
	internal.departments,
	internal.employees,
	internal.job_grades,
	internal.jobs,
	internal.locations,
	internal.regions 
TO "BigManager";

GRANT SELECT ON 
	internal.job_history 
TO "BigManager"; 

CREATE ROLE "EmpJohn" WITH LOGIN PASSWORD 'john';
CREATE ROLE "EmpJane" WITH LOGIN PASSWORD 'jane';

GRANT "BigEmployee" TO "EmpJohn";
--GRANT "BigEmployee" TO "EmpJane";
GRANT "BigManager" TO "EmpJane";

/*
===========
Function 1:
===========
*/

CREATE OR REPLACE FUNCTION internal.get_employee_info_history(param_employee_id INTEGER)
RETURNS TABLE
(
	Employee_ID	 	INTEGER,
	Start_Date 		DATE,
	End_Date 		DATE,
	First_Name 		VARCHAR(20),
	Last_Name 		VARCHAR(25),
	Email 			VARCHAR(25),
	Phone_Number 	VARCHAR(20),
	Hire_Date 		DATE,
	Job_ID 			VARCHAR(10),
	Salary 			MONEY,
	Commission_Pct 	INTEGER,
	Manager_ID 		INTEGER,
	Department_ID 	INTEGER
)
LANGUAGE PLPGSQL
AS
$$

DECLARE	
	rec RECORD;

BEGIN

	IF (EXISTS (SELECT FROM internal.employees e WHERE e.employee_id = param_employee_id)) THEN

		FOR rec IN 
		(	
			SELECT
			*

			FROM
			internal.employees INNER JOIN internal.job_history USING (employee_id)

			WHERE
			internal.employees.employee_id = param_employee_id

			ORDER BY
			internal.job_history.start_date ASC
		)
		LOOP
			Employee_ID := rec.Employee_ID;
			Start_Date := rec.Start_Date;
			End_Date := rec.End_Date; 
			First_Name := rec.First_Name;
			Last_Name := rec.Last_Name;
			Email := rec.Email;
			Phone_Number := rec.Phone_Number;
			Hire_Date := rec.Hire_Date;
			Job_ID := rec.Job_ID;
			Salary := rec.Salary;
			Commission_Pct := rec.Commission_Pct;
			Manager_ID := rec.Manager_ID;
			Department_ID := rec.Department_ID;
		RETURN NEXT;
		END LOOP;

	ELSE
		RAISE EXCEPTION 'No matching record with that ID was found. Please check argument value!';

	END IF;
END
$$;

-- Run the function:

SELECT
*

FROM 
internal.get_employee_info_history(1);


/*
==========
Trigger 1:
==========
*/

ALTER TABLE internal.Jobs ADD COLUMN IF NOT EXISTS last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Declare Trigger Function:

CREATE OR REPLACE FUNCTION internal.jobs_last_update()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS
$$
DECLARE
BEGIN
	NEW.last_update := CURRENT_TIMESTAMP;
	RETURN NEW;
END;
$$;

-- Declare Trigger:

CREATE OR REPLACE TRIGGER trigger_jobs_last_update
	BEFORE UPDATE OR INSERT
	ON internal.Jobs
	FOR EACH ROW 
	EXECUTE PROCEDURE internal.jobs_last_update();

-- Insert Test: Verify that the last_update field is overridden with the current timestamp, even if we try to manually set this ourselves.

INSERT INTO internal.Jobs (job_id, job_title, min_salary, max_salary, last_update) 
	VALUES ('TEST', 'Testing', 0, 1, '1999-01-01')
	
RETURNING *;

/*
==========
Trigger 2:
==========

A more robust solution might also search for what was previously the latest entry with Job_ID = OLD.Job_ID for the employee to be updated in the job_history table and set its End_Date to the current date prior to the update operation. However, the assignment's instructions only ask that we add a new record to the job_history table, not change any that may already exist. Insert was also included in the solution below.
*/

-- Declare Trigger Function:

CREATE OR REPLACE FUNCTION internal.employee_job_history_audit()
RETURNS TRIGGER
LANGUAGE PLPGSQL
AS
$$
DECLARE
BEGIN
	IF (TG_OP = 'UPDATE') THEN
		IF NOT (NEW.Job_ID = OLD.Job_ID) THEN			
			INSERT INTO internal.job_history(Employee_ID, Start_Date, End_Date, Job_ID, Department_ID)
			VALUES (NEW.Employee_ID, CURRENT_TIMESTAMP, null, NEW.Job_ID, NEW.Department_ID);
			RETURN NEW;
		ELSE
			RETURN NULL;
		END IF;
	ELSE
		INSERT INTO internal.job_history(Employee_ID, Start_Date, End_Date, Job_ID, Department_ID)
		VALUES (NEW.Employee_ID, CURRENT_TIMESTAMP, null, NEW.Job_ID, NEW.Department_ID);
		RETURN NEW;
	END IF;
END;
$$;

-- Declare Trigger:

CREATE OR REPLACE TRIGGER trigger_employee_job_history_audit
	AFTER UPDATE OR INSERT
	ON internal.Employees
	FOR EACH ROW 
	EXECUTE PROCEDURE internal.employee_job_history_audit();

/*
===========
Function 2:
===========
*/

CREATE OR REPLACE FUNCTION check_actor_collab(param_actor_id_1 INTEGER, param_actor_id_2 INTEGER)
RETURNS BOOLEAN
LANGUAGE PLPGSQL
AS
$$

DECLARE	

BEGIN

	IF (EXISTS 
			(SELECT
			*

			FROM
				(SELECT
				*

				FROM
				film_actor

				WHERE
				actor_id = param_actor_id_1) AS a1

			INNER JOIN

				(SELECT 
				*

				FROM
				film_actor

				WHERE
				actor_id = param_actor_id_2) AS a2

			USING (film_id))
		) 
		THEN RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END
$$;

-- Returns FALSE:

SELECT
*

FROM
check_actor_collab(199, 35);

-- Returns TRUE:

SELECT
*

FROM
check_actor_collab(1, 20);

