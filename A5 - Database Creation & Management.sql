/*
===================================
Create Database Named "BigCompany":
===================================
*/

CREATE DATABASE "BigCompany" WITH 
	ENCODING = 'UTF-8'
	OWNER = postgres
	CONNECTION LIMIT = -1;

/*
===============================
Create Schema Named "internal":
===============================

(Remember to connect to the BigCompany database first!)

Per PostgreSQL's documentation (https://www.postgresql.org/docs/current/sql-createschema.html), multiple tables can be declared within the same schema that the CREATE SCHEMA command is being used to make by listing every CREATE TABLE subcommand BEFORE the terminating semicolon. These are not separated by commas or semicolons. Every created table will belong to this new schema, which spares us from having to use fully qualified names (though that's a perfectly valid approach, too). This method has one downside: We can't use IF NOT EXISTS.
*/

CREATE SCHEMA internal

	/*
	==============
	Regions Table:
	==============
	*/

	CREATE TABLE IF NOT EXISTS Regions
	(
		Region_ID 		SERIAL PRIMARY KEY,
		Region_Name 	VARCHAR(25)
	)

	/*
	=======================
	Behavior Upon Deletion:
	=======================
	
	If a region is deleted, what should happen? The ERD says that a country must have a valid region_ID... it cannot be null. Should all of the countries that belong to the deleted region also be deleted? If so, does this extend to locations, which must have a valid country_id? ON DELETE CASCADE means that any time a referenced row is deleted, any rows referencing it will be deleted as well. 

	Since there are no rules telling us what we should do, we're going to play it safe and stick with the default behavior (i.e., "NO ACTION"). Per postgreSQL's documentation (https://www.postgresql.org/docs/9.2/ddl-constraints.html), this is similar to RESTRICT; it forbids the deletion of a row in a parent table if there is a row in a derived table that is referencing it (for example, a region cannot be deleted if a country references it, a country cannot be deleted if a location references it, and a location cannot be deleted if a department references it). However, unlike RESTRICT, NO ACTION "allows the check to be deferred until later in the transaction."

	One exception to our deletion policy can be found in the `Employees` table. Since Employees.Manager_ID is optional to Employees, when a referenced employee is deleted, we can simply change the value for Employees.Manager_ID to null.
	*/

	/*
	================
	Countries Table:
	================
	*/

	-- Region_ID cannot be null; according to the ERD, Regions is mandatory to Countries.
	
	CREATE TABLE IF NOT EXISTS Countries
	(
		Country_ID 		CHAR(2) PRIMARY KEY,
		Country_Name 	VARCHAR(40),
		Region_ID 		INT NOT NULL,
		
		FOREIGN KEY (Region_ID) REFERENCES Regions (Region_ID)
	)

	/*
	================
	Locations Table:
	================
	*/

	-- Country_ID cannot be null; according to the ERD, Countries is mandatory to Locations.
	
	CREATE TABLE IF NOT EXISTS Locations
	(
		Location_ID 	SERIAL PRIMARY KEY,
		Street_Address 	VARCHAR(25),
		Postal_Code 	VARCHAR(12),
		City 			VARCHAR(30),
		State_Province 	VARCHAR(12),
		Country_ID 		CHAR(2) NOT NULL,
		
		FOREIGN KEY (Country_ID) REFERENCES Countries (Country_ID)
	)

	/*
	===========
	Jobs Table:
	===========
	*/

	CREATE TABLE IF NOT EXISTS Jobs
	(
		Job_ID 			VARCHAR(10) PRIMARY KEY,
		Job_Title 		VARCHAR(35),
		Min_Salary 		MONEY DEFAULT 0.0::MONEY,
		Max_Salary 		MONEY DEFAULT 1000000::MONEY,
		
		CHECK (Min_Salary >= 0.0::MONEY AND Max_Salary >= 0.0::MONEY),
		CHECK (Min_Salary <= Max_Salary)
	)

	/*
	===============================
	Cyclic Foreign Key Constraints:
	===============================
	
	The `Departments` and `Employees` tables require special attention. Looking at the ERD, there are two relationships between these entities: 
	
	--------------------------------------------------------------------------------
	Departments.Manager_ID		|O————————————————||		Employees.Employee_ID
	--------------------------------------------------------------------------------
	
	- Employees is MANDATORY to Departments 
		- A department MUST have a manager who is an employee.
	- Departments is OPTIONAL to Employees 
		- An employee is allowed to exist without being the manager of a department.
	
	--------------------------------------------------------------------------------
	Departments.Department_ID	||————————————————|<		Employees.Department_ID
	--------------------------------------------------------------------------------
	
	- Employees is MANDATORY to Departments
		- A department MUST have employees; no department can exist without at least one employee.
	- Departments is MANDATORY to Employees
		- An employee MUST belong to a department.
	
	--------------------------------------------------------------------------------
	
	This creates a chicken/egg scenario: A department can't exist without having a manager who is an employee, yet an employee can't exist without first being attached to a department. Which comes first? 
	
	Without making one of the two FK fields nullable, we need to use deferrable constraints. We'll do this after both tables have been created (Please refer to "Table Alteration After Creation"). 
	
	----------------------
	Additional References:
	----------------------
	
	https://stackoverflow.com/questions/10446641/in-sql-is-it-ok-for-two-tables-to-refer-to-each-other
	https://stackoverflow.com/questions/8394177/complex-foreign-key-constraint-in-sqlalchemy/8395021#8395021
	https://code.likeagirl.io/how-to-deal-with-a-cyclic-foreign-key-constraint-using-postgresql-2acf46719948	
	*/
	
	/*
	==================
	Departments Table:
	==================
	*/
	
	-- Neither Manager_ID nor Location_ID can be null since the ERD depicts both Employees and Locations as mandatory to Departments. There's also a one-to-one relationship between Departments.Manager_ID and Employees.Employee_ID, which means that Departments.Manager_ID must be unique.
	
	CREATE TABLE IF NOT EXISTS Departments
	(
		Department_ID 	SERIAL PRIMARY KEY,
		Department_Name VARCHAR(30),
		Manager_ID 		INT NOT NULL UNIQUE,
		Location_ID 	INT NOT NULL,
		
		FOREIGN KEY (Location_ID) REFERENCES Locations (Location_ID)
	)
	
	/*
	================
	Employees Table:
	================
	
	Neither Job_ID nor Department_ID can be null because both Jobs and Departments are mandatory to Employees. However, Manager_ID can be null because Employees is optional to Employees. On a related note, a CHECK constraint has been added to ensure that Manager_ID is different from Employee_ID. An employee probably shouldn't be allowed to be their own manager.
	*/

	CREATE TABLE IF NOT EXISTS Employees
	(
		Employee_ID	 	SERIAL PRIMARY KEY,
		First_Name 		VARCHAR(20) NOT NULL,
		Last_Name 		VARCHAR(25) NOT NULL,
		Email 			VARCHAR(25) NOT NULL UNIQUE,
		Phone_Number 	VARCHAR(20),
		Hire_Date 		DATE,
		Job_ID 			VARCHAR(10) NOT NULL,
		Salary 			MONEY,
		Commission_Pct 	INT,
		Manager_ID 		INT,
		Department_ID 	INT NOT NULL,
		
		FOREIGN KEY (Job_ID) REFERENCES Jobs (Job_ID),
		FOREIGN KEY (Manager_ID) REFERENCES Employees (Employee_ID) ON DELETE SET NULL,
		
		CHECK(Manager_ID <> Employee_ID)
	)

	/*
	==================
	Job_History Table:
	==================
	*/

	-- Employee_ID, Job_ID, and Department_ID cannot be null. Employees, Departments, and Jobs are all mandatory to Job_History. Since Employee_ID is part of a composite primary key, we don't need to add the NOT NULL constraint (Primary keys already cannot be null).
	
	CREATE TABLE IF NOT EXISTS Job_History
	(
		Employee_ID 	INT,
		Start_Date 		DATE,
		End_Date 		DATE,
		Job_ID 			VARCHAR(10) NOT NULL,
		Department_ID 	INT NOT NULL,
		
		PRIMARY KEY (Employee_ID, Start_Date),

		FOREIGN KEY (Employee_ID) REFERENCES Employees (Employee_ID),
		FOREIGN KEY (Job_ID) REFERENCES Jobs (Job_ID),
		FOREIGN KEY (Department_ID) REFERENCES Departments (Department_ID)
	)

	/*
	=================
	Job_Grades Table:
	=================
	*/

	CREATE TABLE IF NOT EXISTS Job_Grades
	(
		Grade_Level VARCHAR(2) PRIMARY KEY,
		Lowest_Sal MONEY DEFAULT 0.0::MONEY,
		Highest_Sal MONEY DEFAULT 1000000::MONEY,
		
		CHECK (Lowest_Sal >= 0.0::MONEY AND Highest_Sal >= 0.0::MONEY),
		CHECK (Lowest_Sal <= Highest_Sal)
	)
;

-- Set search path so that "internal" schema is first:

SET 
search_path

TO
internal, public;

/*
================================
Table Alteration After Creation:
================================
*/

ALTER TABLE internal.Departments ADD CONSTRAINT FK_Manager_ID 
	FOREIGN KEY (Manager_ID) REFERENCES internal.Employees (Employee_ID) DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE internal.Employees ADD CONSTRAINT FK_Department_ID 
	FOREIGN KEY (Department_ID) REFERENCES internal.Departments (Department_ID) DEFERRABLE INITIALLY IMMEDIATE;

/*
=================================
Populate Tables With Sample Data:
=================================
*/

INSERT INTO internal.Regions (Region_ID, Region_Name) 
VALUES 
	(1, 'North America'),
	(2, 'Europe'),
	(3, 'Asia');

INSERT INTO internal.Countries (Country_ID, Country_Name, Region_ID) 
VALUES 
	('CA', 'Canada', 1),
	('US', 'United States', 1),
	('GB', 'United Kingdom', 2),
	('DE', 'Germany', 2),
	('JP', 'Japan', 3);

INSERT INTO internal.Locations (Street_Address, Postal_Code, City, State_Province, Country_ID) 
VALUES 
	('0032 Del Mar Place', '32868', 'Orlando', 'FL', 'US'),
	('819 Dorton Junction', '999-8241', 'Fukuyama', null, 'JP'),
	('0 Macpherson Drive', '77095', 'Houston', 'TX', 'US'),
	('38729 Briar Crest Alley', '929-1811', 'Ninomiya', null, 'JP'),
	('12923 Westport Pass', 'CT15', 'Sutton', 'ENG', 'GB'),
	('599 Brickson Park Parkway', 'V8J', 'Prince Rupert', 'BC', 'CA'),
	('08179 Bluejay Way', 'H3Z', 'Neepawa', 'MB', 'CA'),
	('0159 Huxley Park', '34132', 'Kassel', 'HE', 'DE'),
	('72 Garrison Avenue', '55124', 'Mainz', 'RLP', 'DE'),
	('383 Judy Avenue', 'J2N', 'Farnham', 'QC', 'CA'),
	('8421 Lakeland Court', '70374', 'Stuttgart', 'BW', 'DE'),
	('9 Texas Avenue', '53726', 'Madison', 'WI', 'US');

INSERT INTO internal.Jobs (Job_ID, Job_Title, Min_Salary, Max_Salary) 
VALUES 
	('WEBDEV', 'Web Developer', 73385, 76697),
	('SENIORDEV', 'Senior Developer', 61732, 82834),
	('VPACC', 'VP Accounting', 41727, 48309),
	('ACCASST', 'Accounting Assistant', 21894, 77067),
	('CHFDSGENGR', 'Chief Design Engineer', 25948, 84348),
	('BIOSTAT', 'Biostatistician', 11887, 89343),
	('LEGASST', 'Legal Assistant', 26238, 76695),
	('SOFTCONST', 'Software Consultant', 43616, 46790),
	('ELECENGR', 'Electrical Engineer', 69536, 75869),
	('FOODCHEM', 'Food Chemist', 77481, 92294),
	('RSRCHASSOC', 'Research Associate', 16773, 45123),
	('GENMGR', 'General Manager', 49653, 63009),
	('PHARM', 'Pharmacist', 72087, 77351),
	('MKTASST', 'Marketing Assistant', 81076, 87040),
	('NURSE', 'Nurse', 66169, 74583),
	('GEO', 'Geologist', 28528, 71997),
	('SAFTECH', 'Safety Technician', 67450, 69630),
	('COSTACC', 'Cost Accountant', 47309, 52195),
	('DEV', 'Developer', 42915, 83158),
	('INTAUDIT', 'Internal Auditor', 38620, 79166),
	('ADMINOFC', 'Administrative Officer', 61377, 90100),
	('MEDIAPLAN', 'Media Planner', 52469, 53876),
	('FINADVISR', 'Financial Advisor', 26059, 48042),
	('SOFTENGR', 'Software Engineer', 57253, 60092),
	('VPQC', 'VP Quality Control', 10269, 86609),
	('CLINSPC', 'Clinical Specialist', 64834, 88031),
	('RSRCHASST', 'Research Assistant', 43922, 55270),
	('PARALEGAL', 'Paralegal', 40137, 92303),
	('STFACC', 'Staff Accountant', 56920, 81552),
	('OP', 'Operator', 39142, 49499),
	('FINANLST', 'Financial Analyst', 39741, 67086),
	('CIVENGR', 'Civil Engineer', 35031, 80693),
	('QCENGR', 'Quality Engineer', 41556, 50123),
	('ANLSTPROG', 'Analyst Programmer', 15785, 26938),
	('SENQCENGR', 'Senior Quality Engineer', 60326, 86096),
	('ASSOCPROF', 'Associate Professor', 19784, 51628);

-- Set contraints to deferred when inserting into the `Departments` and `Employees` tables:

BEGIN;
SET CONSTRAINTS ALL DEFERRED;

INSERT INTO internal.Departments (Department_Name, Manager_ID, Location_ID) 
VALUES 
	('Services', 38, 10),
	('Marketing', 94, 2),
	('Support', 80, 9),
	('Support', 35, 11),
	('Human Resources', 59, 12),
	('Accounting', 76, 3),
	('Legal', 46, 1),
	('Research and Development', 79, 5),
	('Business Development', 95, 5),
	('Support', 90, 2),
	('Sales', 62, 12),
	('Services', 23, 7),
	('Sales', 28, 1),
	('Support', 58, 6),
	('Marketing', 50, 6),
	('Product Management', 87, 7),
	('Sales', 12, 7),
	('Product Management', 53, 9),
	('Human Resources', 33, 8),
	('Product Management', 89, 11),
	('Human Resources', 13, 11),
	('Sales', 20, 10),
	('Training', 55, 4),
	('Marketing', 82, 1),
	('Sales', 92, 3),
	('Research and Development', 52, 3);

INSERT INTO internal.Employees (First_Name, Last_Name, Email, Phone_Number, Hire_Date, Job_ID, Salary, Commission_Pct, Manager_ID, Department_ID) 
VALUES 
	('Lina', 'O''Malley', 'lomalley0@ed.gov', '5396866263', '2008-05-26', 'MEDIAPLAN', 69204, 23, 12, 1), 
	('Dianne', 'Gaye', 'dgaye1@rediff.com', '6642969370', '2014-04-03', 'RSRCHASST', 85552, 22, 13, 2), 
	('Curtice', 'Dunnaway', 'cdunnaway2@dion.ne.jp', '2474117763', '1992-04-09', 'MEDIAPLAN', 62690, 23, 20, 3), 
	('Maxi', 'Hove', 'mhove3@umn.edu', '1622421048', '1951-11-18', 'VPQC', 67480, 27, 23, 4), 
	('Lynea', 'Redmire', 'lredmire4@globo.com', '4433159630', '2022-02-09', 'FINADVISR', 92511, 13, 28, 5), 
	('Paxon', 'Tiernan', 'ptiernan5@sitemeter.com', '1029634540', '1988-05-25', 'MEDIAPLAN', 55990, 20, 33, 6), 
	('Darius', 'Cowling', 'dcowling6@altervista.org', '5311040758', '1975-01-31', 'PARALEGAL', 79712, 17, 35, 7), 
	('Corry', 'Preist', 'cpreist7@goo.ne.jp', '9042150900', '1956-11-08', 'LEGASST', 42786, 19, 38, 8), 
	('Clarance', 'Giannini', 'cgiannini8@smugmug.com', '3145959685', '2019-04-02', 'GEO', 56852, 11, 46, 9), 
	('Alistair', 'Umfrey', 'aumfrey9@slideshare.net', '6121790399', '2009-01-20', 'FINANLST', 99225, 23, 50, 10), 
	('Humfrid', 'MacGettigen', 'hmacgettigena@msn.com', '2007713789', '1980-05-06', 'CIVENGR', 17210, 15, 52, 11), 
	('Arlan', 'Switzer', 'aswitzerb@facebook.com', '7555807032', '1995-07-12', 'PARALEGAL', 33366, 20, null, 12), 
	('Maren', 'Robertsson', 'mrobertssonc@psu.edu', '4031107444', '1962-11-12', 'COSTACC', 61808, 20, null, 13), 
	('Galven', 'Pietzker', 'gpietzkerd@alibaba.com', '6915431879', '1960-04-01', 'SOFTENGR', 51789, 27, 58, 14), 
	('Killian', 'Takis', 'ktakise@drupal.org', '6421574516', '1981-08-16', 'NURSE', 43551, 20, 59, 15), 
	('Leisha', 'Gaythor', 'lgaythorf@over-blog.com', '9967094204', '1960-10-06', 'ADMINOFC', 34087, 29, 62, 16), 
	('Boone', 'Renne', 'brenneg@indiatimes.com', '5447040859', '1960-06-20', 'SENIORDEV', 50366, 13, 76, 17), 
	('Francklyn', 'MacCallester', 'fmaccallesterh@gmpg.org', '8433174447', '1991-11-25', 'ACCASST', 15281, 11, 79, 18), 
	('Britney', 'Berney', 'bberneyi@upenn.edu', '2272813554', '2008-07-14', 'CLINSPC', 72690, 30, 80, 19), 
	('Dill', 'Fawloe', 'dfawloej@github.com', '3829788672', '1993-05-25', 'QCENGR', 73467, 24, null, 20), 
	('Normie', 'Amps', 'nampsk@google.co.jp', '9396870564', '1989-09-07', 'GEO', 38164, 23, 87, 21), 
	('Dale', 'McNalley', 'dmcnalleyl@amazon.com', '3269754495', '2018-04-12', 'ASSOCPROF', 74817, 19, 89, 22), 
	('Jozef', 'Stot', 'jstotm@51.la', '3693953958', '1981-10-21', 'MKTASST', 22034, 21, null, 23), 
	('Drucy', 'Macveigh', 'dmacveighn@uol.com.br', '5652151203', '1959-03-15', 'STFACC', 93055, 11, 92, 24), 
	('Filbert', 'Tromans', 'ftromanso@gizmodo.com', '8029803006', '1989-01-02', 'QCENGR', 48188, 18, 94, 25), 
	('Michael', 'Zoren', 'mzorenp@deliciousdays.com', '9285306011', '1978-09-13', 'COSTACC', 49540, 16, 95, 26), 
	('Rowland', 'Manie', 'rmanieq@yolasite.com', '2944822244', '2001-06-25', 'BIOSTAT', 47154, 25, 12, 1), 
	('Chantalle', 'Ruane', 'cruaner@unesco.org', '5761707780', '1986-01-12', 'SOFTCONST', 61401, 29, null, 2), 
	('Hussein', 'Walden', 'hwaldens@japanpost.jp', '2845438599', '2021-07-23', 'GEO', 35190, 21, 20, 3), 
	('Tobye', 'Darte', 'tdartet@mashable.com', '4271506336', '2006-07-21', 'ELECENGR', 61330, 23, 23, 4), 
	('Alissa', 'Neeve', 'aneeveu@dot.gov', '5784368673', '1996-11-10', 'CLINSPC', 85541, 21, 28, 5), 
	('Clementina', 'Zanussii', 'czanussiiv@hud.gov', '4022261718', '1989-05-13', 'ACCASST', 61230, 25, 33, 6), 
	('Leon', 'Goady', 'lgoadyw@google.ca', '4723084530', '2001-09-08', 'PHARM', 31624, 20, null, 7), 
	('Derick', 'Euels', 'deuelsx@nature.com', '1927842444', '1965-05-23', 'RSRCHASSOC', 23218, 21, 38, 8), 
	('Tannie', 'Hegley', 'thegleyy@hostgator.com', '9995443014', '1984-10-04', 'GEO', 69885, 24, null, 9), 
	('Bradan', 'Rattery', 'bratteryz@cisco.com', '7976542032', '1973-12-13', 'CLINSPC', 46526, 12, 50, 10), 
	('Roosevelt', 'Dearnaley', 'rdearnaley10@stanford.edu', '7556638472', '1992-02-19', 'SOFTENGR', 95517, 28, 52, 11), 
	('Aurelia', 'Dhillon', 'adhillon11@tumblr.com', '5203960841', '2016-08-30', 'QCENGR', 76106, 14, null, 12), 
	('Shayne', 'Oven', 'soven12@google.co.uk', '8137082524', '1974-04-11', 'SAFTECH', 42965, 14, 55, 13), 
	('Ruthann', 'Grinnell', 'rgrinnell13@squidoo.com', '1681377172', '1967-07-29', 'VPACC', 20553, 25, 58, 14), 
	('Kylila', 'Risdale', 'krisdale14@sphinn.com', '8047423342', '1951-11-21', 'SENQCENGR', 30084, 30, 59, 15), 
	('Kippy', 'Motto', 'kmotto15@wikimedia.org', '9045716593', '1992-09-27', 'FINADVISR', 90271, 19, 62, 16), 
	('Christiano', 'Eastmond', 'ceastmond16@walmart.com', '6375031265', '1950-01-02', 'ADMINOFC', 96687, 14, 76, 17), 
	('Fraser', 'Seligson', 'fseligson17@hibu.com', '5686252800', '2019-09-14', 'LEGASST', 47659, 26, 79, 18), 
	('Clyde', 'Oxterby', 'coxterby18@ebay.co.uk', '6328774566', '1961-04-20', 'SAFTECH', 54406, 29, 80, 19), 
	('Nita', 'Hamblyn', 'nhamblyn19@behance.net', '6503117979', '1972-02-07', 'WEBDEV', 20788, 29, null, 20), 
	('Sephira', 'Leschelle', 'sleschelle1a@mysql.com', '3836837299', '1978-09-10', 'ANLSTPROG', 68637, 20, 87, 21), 
	('Alick', 'Wilcocke', 'awilcocke1b@amazon.com', '5904700325', '2020-11-05', 'ASSOCPROF', 36051, 13, 89, 22), 
	('Samuel', 'Smitham', 'ssmitham1c@desdev.cn', '4318857585', '1968-01-17', 'NURSE', 43137, 27, 90, 23), 
	('Brigit', 'Wallbridge', 'bwallbridge1d@si.edu', '4772750095', '1977-08-24', 'RSRCHASST', 45095, 21, null, 24), 
	('Conni', 'Fullagar', 'cfullagar1e@nytimes.com', '3996287708', '1987-07-11', 'FOODCHEM', 44922, 26, 94, 25), 
	('Cole', 'Lief', 'clief1f@linkedin.com', '8541829319', '1994-10-08', 'CIVENGR', 86212, 14, null, 26), 
	('Ferrel', 'Roderigo', 'froderigo1g@cnet.com', '7713297063', '1962-09-23', 'WEBDEV', 37040, 26, null, 1), 
	('Angelle', 'Greschik', 'agreschik1h@tiny.cc', '1901333859', '1974-10-02', 'ANLSTPROG', 71741, 25, 13, 2), 
	('Gnni', 'Harriot', 'gharriot1i@un.org', '8997778428', '1977-05-03', 'SENIORDEV', 27636, 19, null, 3), 
	('Glen', 'Malia', 'gmalia1j@examiner.com', '6101272038', '1977-06-02', 'SOFTCONST', 57750, 22, 23, 4), 
	('Morty', 'Roberto', 'mroberto1k@apache.org', '6517202055', '1951-09-12', 'ACCASST', 19105, 10, 28, 5), 
	('Zsazsa', 'Von Helmholtz', 'zvonhelmholtz1l@blog.com', '9151394155', '1962-11-24', 'PARALEGAL', 17678, 11, null, 6), 
	('Marlie', 'Rowcastle', 'mrowcastle1m@drupal.org', '3549974656', '1986-08-19', 'GENMGR', 86188, 11, null, 7), 
	('Kai', 'Scholcroft', 'kscholcroft1n@4shared.com', '9157336865', '2018-08-01', 'MEDIAPLAN', 69704, 19, 38, 8), 
	('Griffith', 'Skelly', 'gskelly1o@ning.com', '2196614531', '1974-11-18', 'SOFTENGR', 37383, 14, 46, 9), 
	('Garrett', 'Cobden', 'gcobden1p@meetup.com', '2739604813', '1993-06-24', 'LEGASST', 87356, 22, null, 10), 
	('Wain', 'Breston', 'wbreston1q@free.fr', '2781759178', '2021-01-13', 'NURSE', 53243, 24, 52, 11), 
	('Ruprecht', 'Slimming', 'rslimming1r@ucoz.com', '2117281565', '1988-01-02', 'SAFTECH', 74159, 10, 53, 12), 
	('Herc', 'Kalderon', 'hkalderon1s@joomla.org', '2383634303', '1994-02-03', 'PARALEGAL', 92364, 27, 55, 13), 
	('Aubrette', 'Bantham', 'abantham1t@alibaba.com', '8564353588', '2016-03-04', 'FINADVISR', 80378, 19, 58, 14), 
	('Edd', 'Escofier', 'eescofier1u@va.gov', '8829110959', '1987-08-28', 'ELECENGR', 57617, 22, 59, 15), 
	('Martha', 'Burdess', 'mburdess1v@pbs.org', '7113823620', '1959-11-12', 'PHARM', 72414, 13, 62, 16), 
	('Ashbey', 'Tyrwhitt', 'atyrwhitt1w@plala.or.jp', '6263489736', '1982-10-05', 'QCENGR', 34540, 20, 76, 17), 
	('Nada', 'Ethington', 'nethington1x@icio.us', '5143182815', '1975-05-28', 'GENMGR', 97181, 27, 79, 18), 
	('Fayina', 'Heistermann', 'fheistermann1y@fda.gov', '4786433642', '2020-07-02', 'STFACC', 90079, 14, 80, 19), 
	('Adriaens', 'Cathie', 'acathie1z@themeforest.net', '6931968513', '1965-05-24', 'GEO', 56858, 25, 82, 20), 
	('Korey', 'MacKeever', 'kmackeever20@youtube.com', '3206475683', '2013-08-20', 'NURSE', 57094, 16, 87, 21), 
	('Dorisa', 'Convery', 'dconvery21@addtoany.com', '2816158151', '2009-09-20', 'CLINSPC', 20488, 21, 89, 22), 
	('Kendricks', 'McGiveen', 'kmcgiveen22@ocn.ne.jp', '4127549385', '1994-07-29', 'FINANLST', 32091, 17, 90, 23), 
	('Marlena', 'Linnard', 'mlinnard23@mtv.com', '3634829222', '2020-02-04', 'CHFDSGENGR', 42578, 26, null, 24), 
	('Allie', 'MacAdie', 'amacadie24@github.io', '5738976538', '2018-10-13', 'RSRCHASST', 89429, 24, 94, 25), 
	('Ivett', 'Ormiston', 'iormiston25@google.nl', '7269665248', '2000-09-19', 'OP', 89886, 12, 95, 26), 
	('Irwinn', 'Harford', 'iharford26@unblog.fr', '1453460485', '1985-03-13', 'SOFTCONST', 32750, 16, null, 1), 
	('Estrella', 'Castagna', 'ecastagna27@blogspot.com', '5101052306', '1980-11-08', 'VPACC', 36251, 22, null, 2), 
	('Sarina', 'Heddy', 'sheddy28@chron.com', '1031280219', '1980-12-23', 'PARALEGAL', 80883, 24, 20, 3), 
	('Anatol', 'Zorn', 'azorn29@slate.com', '6621798830', '1950-12-28', 'WEBDEV', 33749, 23, null, 4), 
	('Ronica', 'Bright', 'rbright2a@netlog.com', '7959452756', '2001-05-07', 'RSRCHASSOC', 22912, 20, 28, 5), 
	('Tanney', 'Maxfield', 'tmaxfield2b@nsw.gov.au', '8875579618', '1962-04-21', 'CLINSPC', 42356, 24, 33, 6), 
	('Karen', 'Agnolo', 'kagnolo2c@etsy.com', '7532505663', '1975-08-08', 'QCENGR', 76979, 22, 35, 7), 
	('Emilee', 'Nelle', 'enelle2d@nih.gov', '6356063900', '1974-03-03', 'CLINSPC', 77596, 29, 38, 8), 
	('Goran', 'Bartolic', 'gbartolic2e@sfgate.com', '7415382022', '2011-10-03', 'DEV', 71992, 11, null, 9), 
	('Morganica', 'Younglove', 'myounglove2f@opera.com', '4424234933', '1959-11-25', 'FINADVISR', 73877, 26, 50, 10), 
	('Alli', 'Enevoldsen', 'aenevoldsen2g@archive.org', '8519134308', '2001-08-01', 'FINANLST', 42934, 18, null, 11), 
	('Magdalen', 'Messer', 'mmesser2h@pinterest.com', '4172040715', '2005-06-29', 'CHFDSGENGR', 70186, 19, null, 12), 
	('Peria', 'McCoid', 'pmccoid2i@nasa.gov', '5012200576', '1988-03-04', 'ACCASST', 21296, 28, 55, 13), 
	('Carrie', 'Wrigley', 'cwrigley2j@skyrock.com', '7258074831', '2011-02-11', 'SOFTENGR', 17006, 23, null, 14), 
	('Sapphira', 'Bridgeland', 'sbridgeland2k@sbwire.com', '5434553701', '1982-12-09', 'SENQCENGR', 72687, 19, 59, 15), 
	('Amalia', 'Harryman', 'aharryman2l@naver.com', '4246800142', '2013-06-10', 'BIOSTAT', 54730, 10, null, 16), 
	('Marrissa', 'Killingback', 'mkillingback2m@mail.ru', '2686252346', '1953-12-20', 'MKTASST', 42095, 26, null, 17), 
	('Frederic', 'Petrolli', 'fpetrolli2n@alexa.com', '6955971204', '1993-09-09', 'INTAUDIT', 76408, 20, 79, 18), 
	('Florence', 'Cloake', 'fcloake2o@digg.com', '3847918509', '1994-10-07', 'FINADVISR', 24142, 24, 80, 19), 
	('Feliza', 'Rouse', 'frouse2p@zdnet.com', '4079226661', '2019-06-28', 'SOFTCONST', 89266, 24, 82, 20), 
	('Hamlin', 'Satchel', 'hsatchel2q@army.mil', '6216919002', '2008-01-14', 'ADMINOFC', 45034, 14, 87, 21), 
	('Emmalee', 'Smurfit', 'esmurfit2r@meetup.com', '4214336022', '1998-11-29', 'FINANLST', 27455, 25, 89, 22);

COMMIT;

INSERT INTO internal.Job_History (Employee_ID, Start_Date, End_Date, Job_ID, Department_ID) 
VALUES 
	(1, '2008-05-26', null, 'MEDIAPLAN', 1), 
	(2, '2014-04-03', null, 'RSRCHASST', 2), 
	(3, '1992-04-09', null, 'MEDIAPLAN', 3), 
	(4, '1951-11-18', '1998-02-10', 'VPQC', 4), 
	(5, '2022-02-09', null, 'FINADVISR', 5), 
	(6, '1988-05-25', null, 'MEDIAPLAN', 6), 
	(7, '1975-01-31', null, 'PARALEGAL', 7), 
	(8, '1956-11-08', '2013-12-08', 'LEGASST', 8), 
	(9, '2019-04-02', null, 'GEO', 9), 
	(10, '2009-01-20', null, 'FINANLST', 10), 
	(11, '1980-05-06', null, 'CIVENGR', 11), 
	(12, '1995-07-12', null, 'PARALEGAL', 12), 
	(13, '1962-11-12', null, 'COSTACC', 13), 
	(14, '1960-04-01', null, 'SOFTENGR', 14), 
	(15, '1981-08-16', null, 'NURSE', 15), 
	(16, '1960-10-06', '2015-10-01', 'ADMINOFC', 16), 
	(17, '1960-06-20', null, 'SENIORDEV', 17), 
	(18, '1991-11-25', null, 'ACCASST', 18), 
	(19, '2008-07-14', null, 'CLINSPC', 19), 
	(20, '1993-05-25', null, 'QCENGR', 20), 
	(21, '1989-09-07', null, 'GEO', 21), 
	(22, '2018-04-12', null, 'ASSOCPROF', 22), 
	(23, '1981-10-21', null, 'MKTASST', 23), 
	(24, '1959-03-15', '1997-05-13', 'STFACC', 24), 
	(25, '1989-01-02', null, 'QCENGR', 25), 
	(26, '1978-09-13', null, 'COSTACC', 26), 
	(27, '2001-06-25', null, 'BIOSTAT', 1), 
	(28, '1986-01-12', null, 'SOFTCONST', 2), 
	(29, '2021-07-23', null, 'GEO', 3), 
	(30, '2006-07-21', null, 'ELECENGR', 4), 
	(31, '1996-11-10', null, 'CLINSPC', 5), 
	(32, '1989-05-13', null, 'ACCASST', 6), 
	(33, '2001-09-08', null, 'PHARM', 7), 
	(34, '1965-05-23', '2016-07-15', 'RSRCHASSOC', 8), 
	(35, '1984-10-04', null, 'GEO', 9), 
	(36, '1973-12-13', null, 'CLINSPC', 10), 
	(37, '1992-02-19', null, 'SOFTENGR', 11), 
	(38, '2016-08-30', null, 'QCENGR', 12), 
	(39, '1974-04-11', null, 'SAFTECH', 13), 
	(40, '1967-07-29', null, 'VPACC', 14), 
	(41, '1951-11-21', null, 'SENQCENGR', 15), 
	(42, '1992-09-27', null, 'FINADVISR', 16), 
	(43, '1950-01-02', '2003-11-28', 'ADMINOFC', 17), 
	(44, '2019-09-14', null, 'LEGASST', 18), 
	(45, '1961-04-20', null, 'SAFTECH', 19), 
	(46, '1972-02-07', null, 'WEBDEV', 20), 
	(47, '1978-09-10', null, 'ANLSTPROG', 21), 
	(48, '2020-11-05', null, 'ASSOCPROF', 22), 
	(49, '1968-01-17', null, 'NURSE', 23), 
	(50, '1977-08-24', null, 'RSRCHASST', 24), 
	(51, '1987-07-11', null, 'FOODCHEM', 25), 
	(52, '1994-10-08', null, 'CIVENGR', 26), 
	(53, '1962-09-23', null, 'WEBDEV', 1), 
	(54, '1974-10-02', null, 'ANLSTPROG', 2), 
	(55, '1977-05-03', null, 'SENIORDEV', 3), 
	(56, '1977-06-02', null, 'SOFTCONST', 4), 
	(57, '1951-09-12', '1995-02-24', 'ACCASST', 5), 
	(58, '1962-11-24', '2015-08-21', 'PARALEGAL', 6), 
	(59, '1986-08-19', null, 'GENMGR', 7), 
	(60, '2018-08-01', null, 'MEDIAPLAN', 8), 
	(61, '1974-11-18', null, 'SOFTENGR', 9), 
	(62, '1993-06-24', null, 'LEGASST', 10), 
	(63, '2021-01-13', null, 'NURSE', 11), 
	(64, '1988-01-02', null, 'SAFTECH', 12), 
	(65, '1994-02-03', null, 'PARALEGAL', 13), 
	(66, '2016-03-04', null, 'FINADVISR', 14), 
	(67, '1987-08-28', null, 'ELECENGR', 15), 
	(68, '1959-11-12', '2005-02-20', 'PHARM', 16), 
	(69, '1982-10-05', '1997-08-27', 'QCENGR', 17), 
	(70, '1975-05-28', null, 'GENMGR', 18), 
	(71, '2020-07-02', null, 'STFACC', 19), 
	(72, '1965-05-24', null, 'GEO', 20), 
	(73, '2013-08-20', null, 'NURSE', 21), 
	(74, '2009-09-20', null, 'CLINSPC', 22), 
	(75, '1994-07-29', null, 'FINANLST', 23), 
	(76, '2020-02-04', null, 'CHFDSGENGR', 24), 
	(77, '2018-10-13', null, 'RSRCHASST', 25), 
	(78, '2000-09-19', null, 'OP', 26), 
	(79, '1985-03-13', null, 'SOFTCONST', 1), 
	(80, '1980-11-08', null, 'VPACC', 2), 
	(81, '1980-12-23', null, 'PARALEGAL', 3), 
	(82, '1950-12-28', '2000-07-08', 'WEBDEV', 4), 
	(83, '2001-05-07', null, 'RSRCHASSOC', 5), 
	(84, '1962-04-21', null, 'CLINSPC', 6), 
	(85, '1975-08-08', null, 'QCENGR', 7), 
	(86, '1974-03-03', null, 'CLINSPC', 8), 
	(87, '2011-10-03', null, 'DEV', 9), 
	(88, '1959-11-25', null, 'FINADVISR', 10), 
	(89, '2001-08-01', null, 'FINANLST', 11), 
	(90, '2005-06-29', null, 'CHFDSGENGR', 12), 
	(91, '1988-03-04', null, 'ACCASST', 13), 
	(92, '2011-02-11', null, 'SOFTENGR', 14), 
	(93, '1982-12-09', null, 'SENQCENGR', 15), 
	(94, '2013-06-10', null, 'BIOSTAT', 16), 
	(95, '1953-12-20', '2005-10-09', 'MKTASST', 17), 
	(96, '1993-09-09', null, 'INTAUDIT', 18), 
	(97, '1994-10-07', null, 'FINADVISR', 19), 
	(98, '2019-06-28', null, 'SOFTCONST', 20), 
	(99, '2008-01-14', null, 'ADMINOFC', 21), 
	(100, '1998-11-29', null, 'FINANLST', 22),
	(100, '2022-01-01', null, 'FINANLST', 22);

INSERT INTO internal.Job_Grades (Grade_Level, Lowest_Sal, Highest_Sal) 
VALUES 
	('L1', 10000, 25000),
	('L2', 25000, 50000),
	('L3', 50000, 75000),
	('L4', 75000, 100000);

/*
==================
Example of UPDATE:
==================
*/

-- Change the first name of employee w/ ID = 1 from 'Lina' to 'Linda':

UPDATE internal.Employees
SET First_Name = 'Linda'
WHERE Employee_ID = 1
RETURNING *;

/*
==================
Example of DELETE:
==================
*/

-- Remove duplicate job_history entry for employee w/ ID = 100:

DELETE FROM internal.Job_History
WHERE Employee_ID = 100 AND Start_Date = '2022-01-01'
RETURNING *;