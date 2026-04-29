use ipl;

-- -- OBJECTIVE QUESTION 

-- Q1. List the different dtypes of columns in table “ball_by_ball” (using information schema)

SELECT COLUMN_NAME,DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME="ball_by_ball";

-- Q2. What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)

Select sum(b.Runs_Scored + coalesce(e.Extra_Runs, 0)) AS Total_Runs
from ball_by_ball b
join matches m on b.Match_Id = m.Match_Id
join team t on b.Team_Batting = t.Team_Id
left join extra_runs e ON b.Match_Id = e.Match_Id 
 and b.Over_Id = e.Over_Id 
 and b.Ball_Id = e.Ball_Id 
 and b.Innings_No = e.Innings_No
where m.Season_Id = 6
and t.Team_Name = "Royal Challengers Bangalore";   

-- Q3. How many players were more than the age of 25 during season 2014?

SELECT 
	COUNT(DISTINCT p.player_id) as Total_player_above25 
FROM 
	player p
INNER JOIN player_match pm ON p.player_id = pm.player_id
INNER JOIN matches m ON m.match_id = pm.match_id
WHERE TIMESTAMPDIFF(YEAR,p.dob,'2014-01-01') >25
 AND m.season_id = (SELECT season_id FROM season
 WHERE season_year='2014');        

--   Q4. How many matches did RCB win in 2013? 

SELECT COUNT(*) AS TOTAL_WIN_BY_RCB_2013
FROM matches                  
WHERE Match_Winner=2 AND YEAR(Match_Date)=2013;	

--  Q5. List the top 10 players according to their strike rate in the last 4 seasons

Select p.Player_Name, sum(b1.Runs_Scored) as Total_Run, count(*) as Balls_Faced,
    round(sum(b1.Runs_Scored) * 100.0 / count(*), 2) as Strike_Rate
from ball_by_ball b1
join matches m on b1.Match_Id = m.Match_Id
join season s on m.Season_Id = s.Season_Id
join player p on b1.Striker = p.Player_Id
where s.Season_Year >= (select max(Season_Year) - 3 from season)
group by p.Player_Name
order by Strike_Rate desc limit 10;

-- Q6. What are the average runs scored by each batsman considering all the seasons?

SELECT p.Player_Name, SUM(Runs_Scored) AS Total_Runs,
       COUNT(DISTINCT Match_ID) AS Innings_Played,
       ROUND(SUM(Runs_Scored)/COUNT(DISTINCT Match_ID),2) AS BATTING_AVERAGE
FROM ball_by_ball b
JOIN player p
ON b.Striker=p.Player_ID
GROUP BY Player_Name
ORDER BY BATTING_AVERAGE DESC;		

-- --  Q7. What are the average wickets taken by each bowler considering all the seasons

SELECT 
    p.player_name,
    COUNT(wt.player_out) / COUNT(DISTINCT m.season_id) AS avg_wickets_per_season
FROM 
    player p
JOIN 
    ball_by_ball b ON b.bowler = p.player_id
JOIN 
    wicket_taken wt ON wt.match_id = b.match_id AND wt.over_id = b.over_id AND wt.ball_id = b.ball_id
JOIN 
    matches m ON m.match_id = b.match_id
GROUP BY 
    p.player_name
ORDER BY 
    avg_wickets_per_season DESC;

-- Q8. List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average.
     
with playerbattingstats as (
  select p.player_id, p.player_name, sum(bbb.runs_scored) as total_runs_scored
  from ball_by_ball bbb
  join player p on bbb.striker = p.player_id
  group by p.player_id, p.player_name),
playerdismissals as (
  select wt.player_out as player_id, count(*) as total_times_out
  from wicket_taken wt
  group by wt.player_out),
playerbattingaverage as (
  select s.player_id, s.player_name,
         case when coalesce(d.total_times_out,0) = 0 then null
              else (s.total_runs_scored) / d.total_times_out end as batting_avg
  from playerbattingstats s
  left join playerdismissals d on s.player_id = d.player_id),
playerbowlingstats as (
  select bb.bowler as player_id, count(*) as total_wickets
  from wicket_taken wt
  join ball_by_ball bb
    on bb.match_id  = wt.match_id
   and bb.innings_no = wt.innings_no
   and bb.over_id    = wt.over_id
   and bb.ball_id    = wt.ball_id
    join out_type ot on ot.out_id = wt.kind_out
 where  ot.out_name not  in ('caught','run out ','retired hurt','stumped','obstructing the field')
  group by bb.bowler),
overall as (
  select
    (select avg(batting_avg) from playerbattingaverage) as overall_batting_avg,
    (select avg(total_wickets) from playerbowlingstats) as overall_wickets_avg
)
select
  pba.player_id,
  pba.player_name,
  round(pba.batting_avg, 2) as batting_avg,
  pbs.total_wickets,
  round(o.overall_batting_avg, 2) as overall_batting_avg,
  round(o.overall_wickets_avg, 2) as overall_wickets_avg
from playerbattingaverage pba
join playerbowlingstats pbs on pba.player_id = pbs.player_id
cross join overall o
where pba.batting_avg > o.overall_batting_avg
  and pbs.total_wickets > o.overall_wickets_avg
order by pba.batting_avg desc, pbs.total_wickets desc;

-- -- This query lists players who have both an average runs scored greater than the overall average and total wickets taken greater than the overall average. 
-- -- It first calculates total wickets for each player, then determines the overall average wickets, and finally filters players based on these criteria.                          


--  Q9. Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.

create table rcb_records (
    Venue_Id int not null,
    Venue_Name varchar(450) not null,
    Wins int default 0,
    Losses int default 0,
  primary key (Venue_Id));
insert into rcb_record (Venue_Id, Venue_Name, Wins, Losses)
select v.Venue_Id, v.Venue_Name,
    count(case when m.Match_Winner = 1 then 1 else null end) As Wins,  
    count(case when m.Match_Winner != 1 then 1 else null end) As Losses
from matches m
join Venue v ON m.Venue_Id = v.Venue_Id
where (m.Team_1 = 1 or m.Team_2 = 1)  
group by v.Venue_Id, v.Venue_Name;


-- This script creates a table named rcb_record to track the wins and losses of Royal Challengers Bangalore (RCB) at individual venues. 
-- It inserts data by counting wins and losses based on match results where RCB is either Team 1 or Team 2.

-- --  Q10. What is the impact of bowling style on wickets taken?

select bs.Bowling_skill, count(wt.Player_Out) as Wicket_taken
from ball_by_ball as bb
join wicket_taken as wt on bb.Match_Id = wt.Match_Id 
           and  bb.Innings_No = wt.Innings_No 
		   and bb.Over_Id = wt.Over_Id and bb.Ball_Id = wt.Ball_Id
join player as p on bb.Bowler = p.Player_Id
join bowling_style as bs on p.Bowling_skill = bs.Bowling_Id
group by bs.Bowling_skill;


-- --  Q11. Write the SQL query to provide a status of whether the performance of the team is better than the previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken 

with team_runs as (select m.Season_Id, b.Team_Batting AS Team_Id, sum(b.Runs_Scored) as Total_Runs
from Ball_by_Ball b
join Matches m on b.Match_Id = m.Match_Id
group by m.Season_Id, b.Team_Batting),

team_wickets as (select m.Season_Id, b.Team_Bowling AS Team_Id, count(w.Player_Out) as Total_Wickets
from Ball_by_Ball b
join Matches m ON b.Match_Id = m.Match_Id
join Wicket_Taken w on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id
and b.Innings_No = w.Innings_No
group by m.Season_Id, b.Team_Bowling),

combined as (select r.Season_Id, r.Team_Id, r.Total_Runs, w.Total_Wickets
from team_runs r
join team_wickets w on r.Season_Id = w.Season_Id and r.Team_Id = w.Team_Id),

with_previous as (
select c.*, s.Season_Year, lag(c.Total_Runs) over (partition by c.Team_Id order by s.Season_Year) as Prev_Total_Runs,
                           lag(c.Total_Wickets) over (partition by c.Team_Id order by s.Season_Year) as Prev_Total_Wickets
from combined c
join Season s on c.Season_Id = s.Season_Id)

select t.Team_Name, wp.Season_Year, wp.Total_Runs, wp.Total_Wickets, wp.Prev_Total_Runs, wp.Prev_Total_Wickets,
   CASE
    when wp.Total_Runs > wp.Prev_Total_Runs and wp.Total_Wickets > wp.Prev_Total_Wickets then 'Better'
    when wp.Total_Runs < wp.Prev_Total_Runs and wp.Total_Wickets < wp.Prev_Total_Wickets then 'Worse'
	else 'Same'
    end as Performance_Status
from with_previous wp
join Team t on wp.Team_Id = t.Team_Id
where wp.Prev_Total_Runs is not null and wp.Prev_Total_Wickets is not null
order by t.Team_Name, wp.Season_Year;


-- -- This query evaluates the performance of each team by comparing total runs scored and wickets taken in the current season against the previous season. 
-- -- It calculates total runs and wickets, combines the data, and determines if the performance is 'Better' or 'Worse' than the previous year.

-- --  Q12. Can you derive more KPIs for the team strategy?

-- 1. Win Percentage:
SELECT 
    t.team_name,
    COUNT(CASE WHEN m.match_winner = t.team_id THEN 1 END) * 100.0 / COUNT(*) AS win_percentage
FROM 
    matches m
JOIN 
    team t ON t.team_id = m.team_1 OR t.team_id = m.team_2
GROUP BY 
    t.team_name;

-- -- 2.Average Runs per Match
SELECT 
    t.team_name,
    SUM(b.runs_scored) / COUNT(DISTINCT m.match_id) AS avg_runs_per_match
FROM 
    ball_by_ball b
JOIN 
    matches m ON b.match_id = m.match_id
JOIN 
    team t ON b.team_batting = t.team_id
GROUP BY 
    t.team_name
ORDER BY 
    avg_runs_per_match DESC;

-- -- 3. Average Wickets per Match
SELECT 
    t.team_name,
    COUNT(w.player_out) / COUNT(DISTINCT m.match_id) AS avg_wickets_per_match
FROM 
    wicket_taken w
JOIN 
    ball_by_ball b ON w.match_id = b.match_id AND w.over_id = b.over_id AND w.ball_id = b.ball_id
JOIN 
    matches m ON w.match_id = m.match_id
JOIN 
    team t ON b.team_bowling = t.team_id
GROUP BY 
    t.team_name
ORDER BY 
    avg_wickets_per_match DESC;

-- -- 4. Run Rate
SELECT 
    t.team_name,
    SUM(b.runs_scored) / (COUNT(DISTINCT m.match_id) * 20) AS run_rate
FROM 
    ball_by_ball b
JOIN 
    matches m ON b.match_id = m.match_id
JOIN 
    team t ON b.team_batting = t.team_id
GROUP BY 
    t.team_name
ORDER BY 
    run_rate DESC;
    
-- -- 5.Toss Impact KPI
SELECT 
    t.team_name,
    td.toss_name AS toss_decision,
    COUNT(CASE WHEN m.toss_winner = m.match_winner THEN 1 END) * 100.0 / COUNT(*) AS win_percentage_after_toss_decision
FROM 
    matches m
JOIN 
    team t ON m.toss_winner = t.team_id
JOIN 
    toss_decision td ON m.toss_decide = td.toss_id
GROUP BY 
    t.team_name, td.toss_name
ORDER BY 
    t.team_name, td.toss_name;

-- --  Q13. Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value.

with Bowler_Avg_Wickets as (select p.Player_Id, p.Player_Name, v.Venue_Name,
        count(wt.Player_Out) / count(distinct m.Match_Id) as Avg_Wickets
    from ball_by_ball bb
    join wicket_taken wt on bb.Match_Id = wt.Match_Id 
        and bb.Innings_No = wt.Innings_No 
        and bb.Over_Id = wt.Over_Id 
        and bb.Ball_Id = wt.Ball_Id
    join player p on bb.Bowler = p.Player_Id
    join matches m on bb.Match_Id = m.Match_Id
    join venue v on m.Venue_Id = v.Venue_Id
    group by p.Player_Id, p.Player_Name, v.Venue_Name)
select Player_Id, Player_Name, Venue_Name, Avg_Wickets,
    row_number() over (order by Avg_Wickets desc) as Wicket_Rank
from Bowler_Avg_Wickets
order by Wicket_Rank;

-- -- This query calculates the average wickets taken by each bowler at each venue. 
-- -- It ranks bowlers based on their average wickets per venue, providing insights into bowler performance in different locations.

-- --  Q14. Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)

WITH Batting as (select p.Player_Id, p.Player_Name, s.Season_Year, sum(b.Runs_Scored) as Total_Runs
from Ball_by_Ball b
join Matches m on b.Match_Id = m.Match_Id
join Season s on m.Season_Id = s.Season_Id
join Player p on b.Striker = p.Player_Id
group by p.Player_Id, p.Player_Name, s.Season_Year
order by p.Player_Name, s.Season_Year),

Bowling as (select p.Player_Id, p.Player_Name, s.Season_Year, count(w.Player_Out) as Total_Wickets
from Ball_by_Ball b
join Wicket_Taken w on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id
and b.Innings_No = w.Innings_No
join Matches m on b.Match_Id = m.Match_Id
join Season s on m.Season_Id = s.Season_Id
join Player p on b.Bowler = p.Player_Id
group by p.Player_Id, p.Player_Name, s.Season_Year
order by p.Player_Name, s.Season_Year)

select b.Player_Id, b.Player_Name, count(distinct b.Season_Year) as best_seasons
from (select Player_Id, Player_Name, Season_Year from Batting where Total_Runs > 400
      UNION ALL
      select Player_Id, Player_Name, Season_Year from Bowling where Total_Wickets > 15) b
group by b.Player_Id, b.Player_Name
having count(distinct b.Season_Year) >= 3
order by best_seasons desc;

-- --  Q15. Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?) 

--  1: Write SQL Queries to Get Player-Venue Performance:
 -- For Batsman (Runs per Venue):
SELECT 
p.Player_Name,
v.Venue_Name,
SUM(b.Runs_Scored) AS Total_Runs
FROM 
    Ball_by_Ball b
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Venue v ON m.Venue_Id = v.Venue_Id
JOIN Player p ON b.Striker = p.Player_Id
GROUP BY 
    p.Player_Name, v.Venue_Name
Order by Total_Runs desc
Limit 10;

-- -- For Bowlers (Wickets per Venue):
SELECT
p.Player_Name,
v.Venue_Name,
COUNT(w.Player_Out) AS Total_Wickets
FROM
Ball_by_Ball b
JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id
AND b.Over_Id = w.Over_Id
AND b.Ball_Id = w.Ball_Id
AND b.Innings_No = w.Innings_No
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Venue v ON m.Venue_Id = v.Venue_Id
JOIN Player p ON b.Bowler = p.Player_Id
GROUP BY
p.Player_Name, v.Venue_Name
Order by Total_wickets desc
Limit 10;


 
-- -
-- -- Subjective Question
-- Q1. How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?

select v.Venue_Name, td.Toss_Name as Toss_Decision, count(*) as Total_Matches,
    sum(case when m.Toss_winner = m.Match_winner then 1 else 0 end) as Matches_Won_After_Toss,
    round(sum(case when m.Toss_winner = m.Match_winner then 1 else 0 end) * 100.0 / count(*), 2) as Win_Percentage
from  matches m
join toss_decision td on m.Toss_Decide = td.Toss_Id
join venue v on m.Venue_Id = v.Venue_Id
group by v.Venue_Name, td.Toss_Name
 order by Total_Matches desc ;


-- 2 Suggest some of the players who would be best fit for the team


-- For Batsman
SELECT
p.Player_Name,
ROUND(SUM(b.Runs_Scored) * 1.0 / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Runs_Per_Match
FROM
Ball_by_Ball b 
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Player p ON b.Striker = p.Player_Id
GROUP BY
p.Player_Name
HAVING COUNT(DISTINCT m.Match_Id) >= 5  -- filters out players who played too few matches
ORDER BY Avg_Runs_Per_Match DESC
LIMIT 10;

-- Top 10 Bowlers with Total Wickets
select p.Player_Name, count(w.Player_Out) as Total_Wickets
from ball_by_ball b
join Wicket_Taken w on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id
and b.Innings_No = w.Innings_No
join Player p on b.Bowler = p.Player_Id
group by p.Player_Name
order by Total_Wickets desc limit 10;

-- 3 What are some of the parameters that should be focused on while selecting the players?

-- For top batsmen
select p.Player_Name, count(*) as Balls_Faced, SUM(b.Runs_Scored) as Total_Runs, round(sum(b.Runs_Scored) * 1.0 / count(*), 2)*100 AS Strike_Rate
from ball_by_ball b
join matches m on b.Match_Id = m.Match_Id
join season s on m.Season_Id = s.Season_Id
join player p on b.Striker = p.Player_Id
where s.Season_Year >= (select max(Season_Year) - 3 from season)
group by p.Player_Name
having count(*) >= 40 -- minimum balls faced
order by Total_Runs desc limit 10;

-- for top Bowlers
select p.Player_Name, count(*) as Balls_Bowled, count(wt.Player_out) as Wickets, round(count(wt.Player_out) * 1.0 / count(*), 2)*100 AS Balls_Bowled_Per_Wicket
from ball_by_ball b
join matches m on b.Match_Id = m.Match_Id
join season s on m.Season_Id = s.Season_Id
join player p on b.Bowler = p.Player_Id
left join wicket_taken wt on b.Match_Id = wt.Match_Id 
                    and b.Over_Id = wt.Over_Id 
                    and b.Ball_Id = wt.Ball_Id
where s.Season_Year >= (select max(Season_Year) - 3 from season)
group by p.Player_Name
having count(*) >= 30 -- min overs
order by Wickets desc, Balls_Bowled_Per_Wicket desc limit 10;

--     
-- 4 Which players offer versatility in their skills and can contribute effectively with both bat and ball? 


select p.Player_Name, coalesce(batting.Total_Runs, 0) as Total_Runs, coalesce(bowling.Total_Wickets, 0) as Total_Wickets
from Player p
left join (select b.Striker as Player_Id, sum(b.Runs_Scored) as Total_Runs
		   from ball_by_ball b
           group by b.Striker) as batting on p.Player_Id = batting.Player_Id
left join (select b.Bowler as Player_Id, count(w.Player_Out) as Total_Wickets
           from ball_by_ball b
           join Wicket_Taken w on b.Match_Id = w.Match_Id 
                       and b.Over_Id = w.Over_Id 
                       and b.Ball_Id = w.Ball_Id 
                       and b.Innings_No = w.Innings_No
           group by b.Bowler) as bowling on p.Player_Id = bowling.Player_Id
where Total_Runs >= 300 and Total_Wickets >= 15
order by Total_Runs desc, Total_Wickets desc;

-- Q5. Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization) 
SELECT
Player_Name,
COUNT(*) AS Matches_Played,
SUM(CASE WHEN Team_Id = Match_Winner THEN 1 ELSE 0 END) AS Matches_Won,
ROUND(SUM(CASE WHEN Team_Id = Match_Winner THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Win_Percentage
FROM (
SELECT DISTINCT
m.Match_Id,
p.Player_Name,
pb.Team_Batting AS Team_Id,
m.Match_Winner
FROM Ball_by_Ball pb
JOIN Matches m ON pb.Match_Id = m.Match_Id
JOIN Player p ON pb.Striker = p.Player_Id
) AS player_matches
GROUP BY Player_Name
HAVING Matches_Played >= 10
ORDER BY Win_Percentage DESC
Limit 10;

-- Q6.What would you suggest to RCB before going to the mega auction?
SELECT
	p.Player_Name,
	COUNT(DISTINCT m.Match_Id) AS Matches_Played,
	SUM(CASE WHEN m.Match_Winner = b.Team_Batting THEN 1 ELSE 0 END) AS Matches_Won,
	ROUND(SUM(CASE WHEN m.Match_Winner = b.Team_Batting THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT m.Match_Id), 2) AS Win_Percentage
FROM 
	Ball_by_Ball b
	JOIN Matches m ON b.Match_Id = m.Match_Id
	JOIN Player p ON b.Striker = p.Player_Id
WHERE 
	b.Team_Batting = 2
GROUP BY 
	p.Player_Name
HAVING 
	Matches_Played >= 10
ORDER BY 
	Win_Percentage DESC
LIMIT 10;

-- Q.7)What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies

-- Identify High-Scoring Matches
select m.Match_Id, t1.Team_Name as Team_1, t2.Team_Name as Team_2, m.Match_Date, m.Win_Margin, m.Match_Winner
from Matches m
join Team t1 on m.Team_1 = t1.Team_Id
join Team t2 on m.Team_2 = t2.Team_Id
where m.Win_Margin is not null
order by m.Win_Margin desc
limit 10;  

-- Identify Teams with High Win Margins
select t.Team_Name, count(m.Match_Id) as Matches_Played, avg(m.Win_Margin) as Average_Win_Margin
from Matches m
join Team t on m.Match_Winner = t.Team_Id
group by t.Team_Name
order by Average_Win_Margin desc;

-- -- Analyze high-scoring matches, team performances, and the impact of individual awards. 
-- -- By running these queries, we can gather insights that can inform team strategies and enhance understanding of factors contributing to high-scoring games.


-- Q8. Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.
SELECT
    t.Team_Name AS Team,
    v.Venue_Name AS Home_Venue,
    COUNT(DISTINCT m.Match_Id) AS Matches_Played_At_Home,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins_At_Home,
    ROUND(SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT m.Match_Id), 2) AS Win_Percentage_At_Home
FROM Matches m
JOIN Venue v ON m.Venue_Id = v.Venue_Id
JOIN Team t ON m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id
WHERE v.Venue_Name LIKE '%Chinnaswamy%'
AND t.team_name ='Royal Challengers Bangalore'
GROUP BY t.Team_Name, v.Venue_Name
ORDER BY Win_Percentage_At_Home DESC;

-- Q9.Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy. 
WITH RCB_Performance AS (
    SELECT
        m.Season_Id,
        COUNT(m.Match_Id) AS Matches_Played,
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Matches_Won,
        SUM(CASE WHEN m.Match_Winner != t.Team_Id THEN 1 ELSE 0 END) AS Matches_Lost,
        (SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) / COUNT(m.Match_Id)) * 100 AS Win_Percentage
    FROM matches m
    INNER JOIN team t ON t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2
    WHERE t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY m.Season_Id
)
SELECT
    s.Season_Year,
    rp.Matches_Played,
    rp.Matches_Won,
    rp.Matches_Lost,
    rp.Win_Percentage
FROM RCB_Performance rp
INNER JOIN season s ON rp.Season_Id = s.Season_Id
ORDER BY s.Season_Year;



-- Q.11)In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

select * from Team where Team_Id = 6;
update Team set Team_Name = "Delhi Daredevils" where Team_Id = 6;


-- Note- already have team name as “Delhi-Daredevils” in a team column.
-- This query updates the "Opponent_Team" column in the "Match" table, replacing all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".
-- also already have a team name "Delhi-Daredevils" in Team table.




