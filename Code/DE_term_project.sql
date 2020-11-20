-- Creating schema for term project
create schema olympicdb;
use olympicdb;

-- Creating table athletes
drop table if exists athletes;
CREATE table athletes
(id integer not null,
athlete VARCHAR(255),
gender VARCHAR(16) NOT NULL,
age integer,
height integer,
weight integer,
nation VARCHAR(255),
nation_code VARCHAR(32),
year_participated varchar(32));

-- After downloading the files from the repository, please check the below and save the files there. The path might be needed to change
SHOW VARIABLES LIKE "secure_file_priv";

-- Loading data into athletes table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olympians.csv' 
INTO TABLE  athletes
FIELDS TERMINATED BY ';' 
LINES TERMINATED BY '\n' 
IGNORE 1 LINES 
(id, athlete, gender, @v_age, @v_height, @v_weight, nation, nation_code, year_participated)
SET
age = nullif(@v_age, ''),
height = nullif(@v_height, ''),
weight = nullif(@v_weight, '');

-- Creating events table
drop table if exists events;
CREATE table events
(id integer not null,
olympic_game varchar(255),
olympic_year varchar(255),
season VARCHAR(255),
city VARCHAR(255),
sport VARCHAR(255),
sport_event varchar(255), 
medal varchar(32));

-- Loading data into events table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/events_final.csv' 
INTO TABLE  events
FIELDS TERMINATED BY ';' 
LINES TERMINATED BY '\n' 
IGNORE 1 LINES 
(id, olympic_game, olympic_year, season, city, sport, sport_event, @v_medal)
SET
medal = nullif(@v_medal, '');

-- Creating countries table
drop table if exists countries;
CREATE table countries
(nation_code varchar(255),
countries varchar(32),
notes varchar(32),
primary key(nation_code));

-- Loading data into countries table
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/country.csv' 
INTO TABLE  countries
FIELDS TERMINATED BY ';' 
LINES TERMINATED BY '\n' 
ignore 1 lines
(nation_code, countries, notes);

-- Joining tables "athletes", "events" and "countries" for a quick glance at the data
SELECT * 
FROM athletes
inner join countries
on athletes.nation_code = countries.nation_code 
left JOIN events
on athletes.id = events.id and athletes.year_participated = events.olympic_year;

-- checking why the nation number was so high in 1900
select count(distinct nation), year_participated from athletes group by year_participated order by year_participated asc;
select distinct nation, year_participated from athletes where year_participated = 1900 order by nation asc;


-- Creating analytical datastore with CreateOlympicDataset storedprocedure and taking a look at the table created
DROP PROCEDURE IF EXISTS CreateOlympicDataset;

DELIMITER //

CREATE PROCEDURE CreateOlympicDataset()
BEGIN

	DROP TABLE IF EXISTS olympics;

	CREATE TABLE olympics AS
	SELECT 
	   athletes.id AS AthletesId, 
	   athletes.athlete AS Name, 
       athletes.gender AS Gender,
       athletes.age AS Age,
       athletes.height as Height,
       athletes.weight as Weight,
       events.olympic_year as Year,
       events.season as Season,
       events.city as City,
	   events.sport As Sport,   
	   events.sport_event As SportEvent,
	   events.medal As Medal,
       countries.countries as Countries
	FROM
		athletes
	left JOIN events 
    on athletes.id = events.id and athletes.year_participated = events.olympic_year
    inner join countries
    on athletes.nation_code = countries.nation_code;

select * from olympics;

END //
DELIMITER ;

CALL CreateOlympicDataset();

-- In the previous look at the table we could spot several problems that need attendance, for example duplicate values and Null values. 
-- Another important thing to note that several already-not-existing nations like Soviet Union, West Germany, etc. transferred under Russia, Germany, etc. during the previous joins under several countries belonged more than one NOC codes. 
-- Now we are checking the olympics dataset for duplicates 
SELECT 
    *,
    count(*)    
FROM 
    olympics
GROUP BY 
    Athletesid, Name, Gender, Age, Year, Season, SportEvent
HAVING 
    COUNT(*) > 1;

-- ETL 
-- Transformation: AS first step we are creating a new table from olympics table which does not have duplicates, due to the operational layer data table joins several duplicate values got created
drop table if exists olympics_final;
create table 
olympics_final 
select distinct AthletesId, Name, Countries, Gender, Age, Height, Weight, Year, Season, City, Sport, SportEvent, Medal
from olympics;

-- Checking the duplicate rows in olympics_final table, which is not much (insignificant).
WITH cte AS (
    SELECT 
        Athletesid, 
        Name,
        Age,
        Gender,
        Year,
        SportEvent,
        Medal,
        ROW_NUMBER() OVER (
            PARTITION BY Athletesid, Name, Age, Gender, Year, SportEvent, Medal
            ORDER BY Athletesid, Name, Age, Gender, Year, SportEvent, Medal) as rownum
    FROM 
        olympics_final
) 
select * FROM cte
WHERE rownum > 1;

-- Further data cleaning, as the null values for age, height and weight are still in the data
-- Counting the null values in age column groupped by gender of analytical data layer
-- The below steps are just for confirmation that there were null values, therefore the average of age, height and weight by gender were calculated. 
select gender, 
SUM(CASE WHEN age IS NULL THEN 1 END) as null_value,
Count(*)
from olympics_final
group by gender;
-- Calculating the average age for athletes by gender
select gender, round(avg(age)) from olympics_final
where age != '0'
group by gender; 

-- Counting the null values in height column
select gender, 
SUM(CASE WHEN height IS NULL THEN 1 END) as null_value,
Count(*)
from olympics_final
group by gender;
-- Calculating the average height for athletes by gender
select round(avg(height)) from olympics_final
where height != '0'
group by gender; 

-- Counting the null values in weight column
select gender, 
SUM(CASE WHEN weight IS NULL THEN 1 END) as null_value,
Count(*)
from olympics_final
group by gender;
-- Calculating the average weight for athletes by gender
select gender, round(avg(weight)) from olympics_final
where weight != '0'
group by gender; 


-- Creating store procedure to clean the analytical data layer, changing the null values of age, height and weight to the average values by gender and changing the values "M" and "F' of gender to "Male" and "Female" 
-- Furthermore, sql safe update needs to be turned off to proceed with updating. In the procedure it is turned on and at the end turned off.
drop procedure if exists CleaningData1;

DELIMITER //

CREATE PROCEDURE CleaningData1()
BEGIN

SET SQL_SAFE_UPDATES = 0;

update olympics_final
set gender = 'Male'
where gender = 'M';

update olympics_final
set gender = 'Female'
where gender = 'F';

select * from olympics_final;

SET SQL_SAFE_UPDATES = 1;

END //
DELIMITER ; 

call CleaningData1();

-- Second data cleaninf procedure described above
drop procedure if exists CleaningData2;

DELIMITER //

CREATE PROCEDURE CleaningData2()
BEGIN

SET SQL_SAFE_UPDATES = 0;

update olympics_final
set age=26
where age is NULL and gender = 'Male';

update olympics_final
set age=24
where age is NULL and gender = 'Female';

update olympics_final
set height = 179 
where height is NULL and gender = 'Male';

update olympics_final
set height = 168
where height is NULL and gender = 'Female';

update olympics_final
set weight = 76 
where weight is NULL and gender = 'Male';

update olympics_final
set weight = 60
where weight is NULL and gender = 'Female';

select * from olympics_final limit 1000;

SET SQL_SAFE_UPDATES = 1;

END //
DELIMITER ; 

CALL CleaningData2();

-- QUESTION1
-- Creating a stored procedure for Medal ranking by country with a categiry called "Success rate" for Summer Olympic Games
drop procedure if exists MedalRanking;
    
DELIMITER //

CREATE PROCEDURE MedalRanking()
BEGIN

select countries as "Countries", count(medal) as "Total medals won", count(distinct athletesid) as "Number of total distinct athletes", count(*) as "Number of participations",
case 
when count(medal) < 20 then 'Needs more work'
when count(medal) > 300 then 'Very successful'
else 'Successful' 
end as "Success rate"
    from olympics_final
    where season = "Summer"
    group by countries
    order by count(medal) desc;

END //
DELIMITER ; 

call MedalRanking();
    
    
-- QUESTION2    
-- StoredProcedure for counting total medal per sport. IN parameter is year, please change year parameter to any given year hen there was either Summer or Winter olympics.
-- Season is added as column to display as in 1992 there was also a summer and winter olympics.
DROP PROCEDURE IF EXISTS GetMedalsPerSportEvent;

DELIMITER //

CREATE PROCEDURE GetMedalsPerSportEvent(
	IN OlympicYear VARCHAR(255)
)
BEGIN
	SELECT year as "Year", sport as "Sport", count(medal) as "Total medals won", season as "Season"
 		FROM olympics_final
			WHERE year = OlympicYear
            group by sport
			order by count(medal) desc;
            
END //
DELIMITER ;

call GetMedalsPerSportEvent('1992');

-- QUESTION3
-- Look at randomly chosen sport for each olympic year and order by total count of medals
DROP PROCEDURE IF EXISTS GetTotalMedalsForSportEventEachYear;

DELIMITER //

CREATE PROCEDURE GetTotalMedalsForSportEventEachYear(
	IN SportEvent VARCHAR(255)
)
BEGIN
	SELECT year, count(medal)
 		FROM olympics_final
			WHERE sport = SportEvent and medal = ('Gold' or medal = 'Silver' or medal = 'Bronze')
            group by year
			order by count(medal) desc;
            
END //
DELIMITER ;

call GetTotalMedalsForSportEventEachYear('Swimming');

-- QUESTION 4
-- Year of first olympic Gold medal in each sport
DROP VIEW IF EXISTS First_Olympic_Golds_Sport;
CREATE VIEW `First_Olympic_Golds_Sport` AS
select sport as "Sport Event", min(year) as "First Gold Medal", max(year) as "Latest Gold Medal"
from olympics_final
where countries = 'Hungary' and medal = 'Gold'
group by sport
order by min(year), max(year);

select * from First_Olympic_Golds_Sport;

-- QUESTION 5
-- Creating a view in which we get all the women gold medals for Hungary
DROP VIEW IF EXISTS Hungary_women_gold_medals;
CREATE VIEW `Hungary_women_gold_medals` AS
SELECT * FROM olympics_final 
WHERE Countries = 'Hungary' and Medal = 'Gold' and Gender = 'Female' 
order by olympics_final.Year desc;

select * from Hungary_women_gold_medals;

-- QUESTION6
-- Average age by gender for each sport in Summer Olympics, in a descending order by average age of males
-- Where the values are Null That sport was not an olympic sport for either women or men
DROP PROCEDURE IF EXISTS AverageAgeForSports;

DELIMITER //

CREATE PROCEDURE AverageAgeForSports()
BEGIN
SELECT * FROM 
( SELECT sport
                ,round(avg(age), 1) AS "Average Male Age"
                ,COUNT( DISTINCT athletesid ) AS "Number Of Male Athletes"
FROM olympics_final
WHERE season = 'Summer' AND gender = 'Male'
GROUP BY sport order by avg(age) desc) AS m
LEFT JOIN  ( SELECT sport
                ,round(avg(age), 1) AS "Average Female Age"
                ,COUNT( DISTINCT athletesid ) AS "Number of Female Athletes"
FROM olympics_final
WHERE season = 'Summer' AND gender = 'Female'
GROUP BY sport ) AS f ON m.sport = f.sport 
UNION
SELECT * FROM ( SELECT sport
                ,round(avg(age), 1) AS "Average Male Age"
                ,COUNT( DISTINCT athletesid ) AS "Number of Male Athletes"
FROM olympics_final
WHERE season = 'Summer' AND gender = 'Male'
GROUP BY sport ) AS m
RIGHT JOIN ( SELECT sport
                ,round(avg(age), 1) AS "Average Female Age"
                ,COUNT( DISTINCT athletesid ) AS "Number of Female Athletes"
FROM olympics_final
WHERE season = 'Summer' AND gender = 'Female'
GROUP BY sport order by avg(age) desc) AS f ON m.sport = f.sport;
 
 END//
Delimiter ;

CALL AverageAgeForSports();

-- QUESTION7
-- Creating view of average age and average participants by sport
DROP VIEW IF EXISTS Average_age_and_NumberOfParticipants;
create view `Average_age_and_NumberOfParticipants` as
select sport, avg(age), count(distinct athletesid)
from olympics_final
where season = 'Summer' 
group by sport
order by avg(age) asc
limit 10;

select * from Average_age_and_NumberOfParticipants;

-- QUESTION8
-- Get the total count of gold medals won by a country in a given olympic year
DROP PROCEDURE IF EXISTS GetMedalCountByCountry;

DELIMITER $$

CREATE PROCEDURE GetMedalCountByCountry (
	IN  countryName VARCHAR(25),
    in olympicYear int,
	OUT total INT
)
BEGIN
	SELECT count(distinct sportevent)
	INTO total
	FROM olympics_final
    where (medal = 'Gold' or medal = 'Silver' or medal = 'Bronze') 
	and countries = countryName
    and year = olympicYear;
END$$
DELIMITER ;

call GetMedalCountByCountry('Hungary', '2016', @total);
select @total;

-- QUESTION9
-- Creating a view to count total gold medals and number of athletes that won gold medals (team sports) by countries in 2016
DROP VIEW IF EXISTS Total_Gold_Medals_In_2016;
CREATE VIEW `Total_Gold_Medals_In_2016` AS
select countries as "Countries", count(distinct sportevent) as "Number of gold medals", count(distinct athletesid) as "Number of distinct gold medal winner athletes"
from olympics_final 
where year='2016' and (medal = 'Gold') 
group by countries 
order by count(distinct sportevent) desc
limit 15;

select * from Total_Gold_Medals_In_2016;

-- QUESTION10
-- Creating view of which athletes won the most total number of olympic medals (top15)
drop view if exists most_successful_athletes; 
create view `Most_successful_athletes` as
select name as "Name", gender as "Gender", sport as "Sport", countries as "Countries", count(medal) as "Total number of medals won", max(distinct year) as "Year of latest medal win"
from olympics_final
group by name
order by count(medal) desc
limit 15;

select * from most_successful_athletes; 

-- EXTRA INTERESTING STUFF
-- Counting different Olympic medals won by distinct sportevent (Only displaying countries that won all three medal types) adn the number of athletes that won it (different due to team events)
DROP Procedure IF EXISTS NumberOfGoldSilverBronzeMedalByCountries;

DELIMITER //

create procedure NumberOfGoldSilverBronzeMedalByCountries(
in OlympicYear Varchar(32) 
) 
begin 
select * from
(select countries as Countries, count(distinct sportevent) as "Number Of Events With Gold Medal", count(distinct athletesid) as "Number Of AThletes With Gold"
from olympics_final 
where year= OlympicYear and (medal = 'Gold') 
group by countries 
order by count(distinct sportevent) desc) as a
inner join
(select countries as Countries, count(distinct sportevent) as "Number Of Events With Silver Medal", count(distinct athletesid) as "Number Of AThletes With Silver"
from olympics_final 
where year= OlympicYear and (medal = 'Silver') 
group by countries 
order by count(distinct sportevent) desc) as b
on a.Countries = b.Countries
inner join
(select countries as Countries, count(distinct sportevent) as "Number Of Events With Bronze Medal", count(distinct athletesid) as "Number Of AThletes With Bronze"
from olympics_final 
where year= OlympicYear and (medal = 'Bronze') 
group by countries 
order by count(distinct sportevent) desc) as c
on a.Countries = c.Countries;

END//
Delimiter ;

CALL NumberOfGoldSilverBronzeMedalByCountries('2016');

-- EXTRA STORED PROCEDURE
-- List of Gold medal winners by a country for all Olympic Events (example Hungary), nation can be changed
-- StoredProcedures to find all the gold medals won by a nation in a descending order by the year of the Olympic Game. Change the name of the country to find out information about other countries as well.
DROP PROCEDURE IF EXISTS GetGoldMedalWinnerByCountry;

DELIMITER //

CREATE PROCEDURE GetGoldMedalWinnerByCountry(
	IN countryName VARCHAR(255)
)
BEGIN
	SELECT * 
 		FROM olympics_final
			WHERE Countries = countryName
            and medal = 'Gold'
            order by year desc;
            
END //
DELIMITER ;

call getgoldmedalwinnerbycountry('Hungary');