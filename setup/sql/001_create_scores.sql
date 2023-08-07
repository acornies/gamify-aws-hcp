CREATE TABLE IF NOT EXISTS scores (
   score_id serial PRIMARY KEY,
   score_type VARCHAR ( 255 ) NULL,
   team_id VARCHAR ( 255 ) NOT NULL,
   score_value INT NOT NULL,
   score_date TIMESTAMP NOT NULL
);