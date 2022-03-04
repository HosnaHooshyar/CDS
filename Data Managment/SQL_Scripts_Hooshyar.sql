--- The dimension tables
CREATE TABLE age_restriction(
age_res_ID int PRIMARY KEY,
age_rate VARCHAR(6) NOT NULL,
reason character varying);

CREATE TABLE Movie_cast(
cast_ID int PRIMARY KEY,
Director_name character varying NOT NULL,
Director_IMDb_page character varying,
Actor_name character varying,
Actor_IMDb_page character varying,
Actor_Gender VARCHAR(6));

CREATE TABLE country(
country_id int PRIMARY KEY,
country_name character varying NOT NULL,
language character varying NOT NULL,
continent character varying NOT NULL);

CREATE TABLE Genre(
Genre_ID int PRIMARY KEY,
Genre_name character varying NOT NULL);

CREATE TABLE Genre_Group(
Genre_group_ID int PRIMARY KEY,
Genre_group_name character varying);

CREATE TABLE Genre_Bridge(
Genre_Bridge_key int,
Genre_key int,
FOREIGN KEY (Genre_Bridge_key) REFERENCES Genre_Group(Genre_group_ID),
FOREIGN KEY (Genre_key) REFERENCES Genre(Genre_ID),
PRIMARY KEY (Genre_Bridge_key, Genre_key));

CREATE TABLE Rating(
Rating_ID int PRIMARY KEY,
IMDb_score float(2) NOT NULL,
IMDb_num_Votes int NOT NULL,
IMDb_num_user_review int,
metascore int);

CREATE TABLE Release_Date(
Date_ID int PRIMARY KEY,
release_date date,
day int,
month int,
year int);

CREATE TABLE Title(
Title_ID int PRIMARY KEY,
Movie_title character varying NOT NULL,
synopsis character varying,
IMDb_Page character varying,
awards_nominations_number int,
awards_won_number int,
oscars_won_number int NOT NULL,
Genre_Group_key int,
FOREIGN KEY (genre_group_key) REFERENCES genre_group(genre_group_ID));

--- The fact table:
CREATE TABLE Movie_Fact(
title_key int,
Rating_key int,
release_date_key int,
age_key int,
cast_key int,
Country_key int,
boxoffice int,
duration int,
FOREIGN KEY (title_key) REFERENCES title(title_ID),
FOREIGN KEY (Rating_key) REFERENCES rating(rating_ID),
FOREIGN KEY (release_date_key) REFERENCES release_date(date_ID),
FOREIGN KEY (age_key) REFERENCES age_restriction(age_res_ID),
FOREIGN KEY (cast_key) REFERENCES Movie_cast(cast_ID),
FOREIGN KEY (Country_key) REFERENCES Country(Country_ID));

--- Finding the genres of "12 Years a slave"
SELECT genre_name
FROM title JOIN genre_group ON genre_group_key = genre_group_id
    JOIN genre_bridge ON genre_group_id = genre_bridge_key
    JOIN genre ON genre_key = genre_id
WHERE movie_title = '12 Years a Slave'

--- Question 1
SELECT age_rate, reason, SUM(oscars_won_number) AS Oscar,
    SUM(awards_won_number) AS Awards
FROM age_restriction JOIN movie_fact ON age_res_ID = age_key
    JOIN title ON title_key = title_ID
GROUP BY (age_rate,reason)
ORDER BY SUM(oscars_won_number) DESC

--- Question 2
SELECT IDK.Director_name, maxOscars, boxoffice/100000 AS gross_in_million,duration,
movie_title, year
FROM (
    SELECT movie_cast.Director_name, maxOscars, cast_id
    FROM(
        SELECT Director_name, maxOscars
        FROM
            (SELECT MAX(count) as maxOscars 
            FROM (
                SELECT Director_name, count(*) as count
                FROM movie_cast
                GROUP BY Director_name) as x 
                    ) max_director,
            (SELECT Director_name, count(*) as count
            FROM movie_cast
            GROUP BY Director_name) num_director
        WHERE maxOscars = count) AS max_director_table,
    movie_cast
    WHERE max_director_table.Director_name = movie_cast.Director_name) AS IDK JOIN   movie_fact
ON cast_id = cast_key JOIN title
ON title_id = title_key JOIN release_date
ON date_id = release_date_key
ORDER BY boxoffice DESC

--- Creating the view
CREATE OR REPLACE VIEW movie_view AS
SELECT *
FROM Movie_Fact, age_restriction, Movie_cast, country, Genre_Group,
    Rating, Release_Date, Title
WHERE age_key = age_res_ID
    AND cast_key = cast_ID
    AND Country_key = country_id
    AND genre_group_key = Genre_group_ID
    AND Rating_key = Rating_ID
    AND release_date_key = Date_ID
    AND title_key = Title_ID

--- CUBE query
SELECT country_name AS country, language, SUM(awards_won_number) AS awards,
    SUM(oscars_won_number) AS Oscars
FROM movie_view
WHERE country_name NOT IN ('United States')
GROUP BY CUBE (country_name, language)

--- ROLLUP query
SELECT genre_name, movie_view.year, COUNT(*) AS count,
    SUM(awards_won_number) AS awards
FROM movie_view 
    JOIN genre_bridge ON genre_group_ID = genre_bridge_key
    JOIN genre ON genre_key = genre_id
GROUP BY ROLLUP(genre_name,movie_view.year)
ORDER BY year DESC, count DESC

--- GROUPING SETS query
SELECT age_rate,genre_group_name AS genres, country_name, language,
    trunc((SUM(boxoffice::numeric)/1000000),2) AS profit_in_million
FROM movie_view
WHERE (imdb_score >= 9 OR metascore >= 90)
GROUP BY GROUPING SETS ((age_rate,genre_group_name),
                        (country_name,language))
ORDER BY SUM(boxoffice) DESC

--- Ranking query
SELECT
    concat(FLOOR(imdb_score), '-', FLOOR(imdb_score) + 1) AS IMDb_score,
    age_rate,
    SUM(boxoffice)/1000000 AS Gross_in_million,
    RANK() OVER ( PARTITION BY concat(FLOOR(imdb_score), '-', FLOOR(imdb_score) + 1)
            ORDER BY SUM(boxoffice)) AS rank_by_gross,
    DENSE_RANK() OVER ( PARTITION BY concat(FLOOR(imdb_score), '-', FLOOR(imdb_score) + 1)
            ORDER BY SUM(boxoffice)) AS DENSErank_by_gross
FROM movie_view
GROUP BY concat(FLOOR(imdb_score), '-', FLOOR(imdb_score) + 1),age_rate

--- Window query
SELECT
    to_char(to_timestamp (month::text, 'MM'), 'TMmonth') AS Release_Month,
    LAG(ROUND(AVG(imdb_num_user_review))) OVER(ORDER BY month) ,
    ROUND(AVG(imdb_num_user_review)) AS num_of_reviews,
    LEAD(ROUND(AVG(imdb_num_user_review))) OVER(ORDER BY month)
FROM movie_view
WHERE release_date > '12/31/2009'
AND release_date < '01/01/2017'
GROUP BY month

--- Period-to-period comparison 
SELECT
    year AS release_year,
    avg_duration, Pre_year_avg_duration,
    avg_duration - Pre_year_avg_duration AS Difference,
    trunc((avg_duration - Pre_year_avg_duration)::numeric/Pre_year_avg_duration::numeric,2)
        AS Difference_per
FROM (
    SELECT year,ROUND(AVG(duration)) AS avg_duration, 
        LAG(ROUND(AVG(duration))) OVER (ORDER BY year) AS Pre_year_avg_duration
    FROM release_date JOIN movie_fact
        ON date_ID = release_date_key JOIN rating
        ON rating_id = rating_key
    WHERE month IN (1,2,3)
    GROUP BY year
    ORDER BY year) AS vote_table
