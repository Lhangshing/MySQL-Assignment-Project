-- PART I: SCHOOL ANALYSIS
use baseball_project;
-- 1. View the schools and school details tables
select *
from schools;
select * from school_details;

-- 2. In each decade, how many schools were there that produced players?
SELECT 
    FLOOR(yearID / 10) * 10 AS decade,
    COUNT(DISTINCT schoolID) AS num_school
FROM
    schools
GROUP BY decade;

-- 3. What are the names of the top 5 schools that produced the most players?
select sd.name_full,
		count(distinct s.playerID) as num_players
from schools s
	LEFt JOIN
		school_details sd
        on s.schoolID = sd.schoolID
group by sd.name_full
Order by num_players DESC
LIMIT 5;

-- 4. For each decade, what were the names of the top 3 schools that produced the most players?

WITH cte as (SELECT 
					FLOOR(s.yearID / 10) * 10 AS decade,
					sd.name_full,
					COUNT(DISTINCT s.playerID) AS num_players      
			FROM
				schools s
				LEFT JOIN
					school_details sd
					on s.schoolID = sd.schoolID
			Group by  decade,sd.name_full),
	sr as (select decade, name_full, num_players,
				DENSE_RANK() over(partition by decade order by num_players DESC) as top_schools
		from cte)
select *
from sr
where top_schools <= 3;


-- PART II: SALARY ANALYSIS
-- 1. View the salaries table
select * from salaries;

-- 2. Return the top 20% of teams in terms of average annual spending
-- yearly top 20% avg spending team
WITH ats as (SELECT 
					yearID, teamID, 
					SUM(salary) AS total_spend
			FROM
					salaries
			GROUP BY teamID, yearID 
			ORDER BY teamID, yearID),
	tpc as (select 	yearID, teamID, 
					avg(total_spend) as avg_total_spend,
					ntile(5) over(partition by yearID order by total_spend DESC) as top_pct
			from ats
            group by teamID, yearID)
select yearID, 
		teamID, 
		round(avg_total_spend/1000000, 2) as avg_spend_millions
from tpc
where top_pct = 1;


-- Overall top 20% avg spending team

with ts as 		(select 	yearID, teamID, SUM(salary) as total_spend
				from 		salaries
				Group by 	yearID, teamID),
	tpct as 	(select 	teamId, 
							avg(total_spend) as avg_total_spend,
							ntile(5) over(order by avg(total_spend) DESC) as top_pct
				from ts
				group by teamID)
select teamID, round(avg_total_spend/1000000,2) as avg_spend_millions
from tpct
where top_pct = 1;

-- 3. For each team, show the cumulative sum of spending over the years
with ts as (select yearID, teamId, sum(salary) as total_spend
			from salaries
			Group by teamID, yearID
			order by teamID, yearID)
select yearID, teamID, total_spend,
		sum(total_spend) over(partition by teamID order by yearID) as cum_spend
from ts;


-- 4. Return the first year that each team's cumulative spending surpassed 1 billion
with ts as (select yearID, teamId, sum(salary) as total_spend
			from salaries
			Group by teamID, yearID
			order by teamID, yearID),
	cs as (select yearID, teamID, total_spend,
					sum(total_spend) over(partition by teamID order by yearID) as cum_spend
			from ts),
	fb as (select yearID, teamId, cum_spend,
					row_number() over(partition by teamID order by yearID) as first_yr
			from cs
			where cum_spend >= 1000000000)
select yearID, teamID, round(cum_spend/1000000000, 3) as cum_spend_bn
from fb
where first_yr = 1;


-- PART III: PLAYER CAREER ANALYSIS
-- 1. View the players table and find the number of players in the table
select * from players;


-- 2. For each player, calculate their age at their first game, their last game, and their career length (all in years). Sort from longest career to shortest career.
-- USING CTE with simple math
with cte as (select
					nameGiven, debut, finalGame,
					CAST(CONCAT(birthYear, '-', birthMonth,'-', birthDay) as date) as dob
			from players)
select nameGiven,
		ROUND(DATEDIFF(debut, dob)/365) as starting_age,
        ROUND(DATEDIFF(finalGame, dob)/365) as ending_age,
        ROUND(DATEDIFF(finalGame, debut)/365) as career_length
from cte
Order by career_length DESC;

-- USING DATE function without cte
select 
	nameGiven, debut, finalGame,
	CAST(CONCAT(birthYear, '-', birthMonth,'-', birthDay) as date) as dob,
    TIMESTAMPDIFF(YEAR, CAST(CONCAT(birthYear, '-', birthMonth,'-', birthDay) as date), debut) as starting_age,
    TIMESTAMPDIFF(YEAR, CAST(CONCAT(birthYear, '-', birthMonth,'-', birthDay) as date), finalGame) as ending_age,
    TIMESTAMPDIFF(YEAR, debut, finalgame) as career_length
    from players
    order by career_length DESC;

-- 3. What team did each player play on for their starting and ending years?
select 	p.nameGiven,
		s.yearID as starting_year, 
        s.teamID as startng_team,
        e.yearID as ending_year,
        e.teamID as ending_team
from players p
		INNER JOIN salaries s
				on p.playerID = s.playerID
				AND YEAR(p.debut) = s.yearID
		INNER JOIN salaries e
				on p.playerID = e.playerID
				AND YEAR(p.finalGame) = e.yearID;

-- 4. How many players started and ended on the same team and also played for over a decade?
-- USING CTE
WITH se as (select 	p.nameGiven,p.debut, p.finalGame,
					s.yearID as starting_year, 
					s.teamID as starting_team,
					e.yearID as ending_year,
					e.teamID as ending_team
			from players p
					INNER JOIN salaries s
							on p.playerID = s.playerID
							AND YEAR(p.debut) = s.yearID
					INNER JOIN salaries e
							on p.playerID = e.playerID
							AND YEAR(p.finalGame) = e.yearID
			where s.teamID = e.teamID)
select nameGiven, 
		starting_year, starting_team,
        ending_year, ending_team,
        timestampdiff(year, debut, finalGame) as career_length
from se
where timestampdiff(year, debut, finalGame) > 10;

-- without CTE
select 	p.nameGiven,
		s.yearID as starting_year, 
		s.teamID as starting_team,
		e.yearID as ending_year,
		e.teamID as ending_team,
        e.yearID - s.yearID as career_length
from players p
		INNER JOIN salaries s
				on p.playerID = s.playerID
				AND YEAR(p.debut) = s.yearID
		INNER JOIN salaries e
				on p.playerID = e.playerID
				AND YEAR(p.finalGame) = e.yearID
where s.teamID = e.teamID
AND e.yearID - s.yearID > 10;

-- PART IV: PLAYER COMPARISON ANALYSIS
-- 1. View the players table
select * from players;

-- 2. Which players have the same birthday?
-- without using CTE - self join
select p1.nameGiven, 
		CONCAT(p1.birthyear, '-',p1.birthMonth, '-',p1.birthDay) as dob1,
        p2.nameGiven,
        CONCAT(p2.birthyear, '-',p2.birthMonth, '-',p2.birthDay) as dob2
from players p1
	INNER JOIN
		players p2
        on CONCAT(p1.birthyear, '-',p1.birthMonth, '-',p1.birthDay) 
			= CONCAT(p2.birthyear, '-',p2.birthMonth, '-',p2.birthDay)
        AND p1.nameGiven != p2.nameGiven;

-- with CTE and Group Concat function

with bd as (select CONCAT(birthyear, '-',birthMonth, '-',birthDay) as dob,
					nameGiven
			from players)
select dob, group_concat(nameGiven separator ', ') as players, count(nameGiven) as num_players
from bd
where dob is not null
group by dob
having count(nameGiven) >= 2
order by count(nameGiven) DESC;


-- 3. Create a summary table that shows for each team, what percent of players bat right, left and both
select * from players;
select * from salaries;
-- using CTE
with tp as (select  s.teamID, 
					count(distinct p.playerID) as num_players,  
					p.bats
			from players p
				inner join
					salaries s on
					p.playerID = s.playerID
			group by s.teamID, p.bats)
select teamID,	
		ROUND(SUM(case when bats = 'R' then num_players end)/sum(num_players) * 100, 2) as right_hand,
		ROUND(sum(case when bats = 'L' then num_players end)/sum(num_players) * 100, 2) as left_hand,
		ROUND(sum(case when bats = 'B' then num_players end)/sum(num_players) * 100, 2) as both_hand,
		sum(num_players) as total_players
from tp
group by teamID
order by total_players DESC;


-- without CTEs

select s.teamID, count(s.playerID) as num_players,
		ROUND(sum(case when bats = 'R' then 1 else 0 end)/count(s.playerID) *100, 2) as bat_right,
        ROUND(sum(case when bats = 'L' then 1 else 0 end)/count(s.playerID) *100, 2) as left_right,
        ROUND(sum(case when bats = 'B' then 1 else 0 end)/count(s.playerID) *100, 2) as both_right
from salaries s
	LEFT JOIN 
    players p on
    s.playerID = p.playerID
GROUP BY teamID
order by num_players DESC;




-- 4. How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?
with avg_m as (select FLOOR(YEAR(debut)/10) * 10 as decade, 
						ROUND(AVG(weight),1) as avg_weight, 
						ROUND(AVG(height),1) as avg_height
				from players
				group by decade)
select decade, avg_weight, avg_height,
		avg_weight - lag(avg_weight) over(order by decade) as avg_w_changes,
        avg_height - lag(avg_height) over(order by decade) as avg_h_changes
from avg_m
where decade is not null;






























