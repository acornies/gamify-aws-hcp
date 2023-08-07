-- query to get scores by team
select team_id, SUM(score_value) from scores GROUP BY team_id;

-- query to get top team from scores
select team_id, SUM(score_value) as TOTAL from scores GROUP BY team_id ORDER BY total DESC;