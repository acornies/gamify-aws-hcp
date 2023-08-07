-- query to get scores by team
SELECT team_id, SUM(score_value) FROM scores GROUP BY team_id;

-- query to get top team from scores
SELECT team_id, SUM(score_value) AS total FROM scores GROUP BY team_id ORDER BY total DESC;