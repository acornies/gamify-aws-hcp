-- INSERT INTO teams (display_name) VALUES ('Debug Thugs');
-- INSERT INTO teams (display_name) VALUES ('Bit Lords');
-- INSERT INTO teams (display_name) VALUES ('Reboot Rebels');
-- INSERT INTO teams (display_name) VALUES ('Byte Dogs');
-- INSERT INTO teams (display_name) VALUES ('Bootstrap Trojans');
-- INSERT INTO teams (display_name) VALUES ('Hugs for Bugs');

-- example score population
INSERT INTO scores (team_id, score_value, score_date) VALUES ('123456789', 10, NOW());
INSERT INTO scores (team_id, score_value, score_date) VALUES ('123456789', 5, NOW());
INSERT INTO scores (team_id, score_value, score_type, score_date) VALUES ('123456789', 1, 'message', NOW());
INSERT INTO scores (team_id, score_value, score_date) VALUES ('323456789', 10, NOW());
INSERT INTO scores (team_id, score_value, score_date) VALUES ('323456789', 1, NOW());
INSERT INTO scores (team_id, score_value, score_type, score_date) VALUES ('323456789', 100, 'message', NOW());