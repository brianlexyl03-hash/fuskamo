-- LOCAL/DEV ONLY — never run against production. Clearly-fake labels, no
-- real names, so no ambiguity about this being real player data.
insert into players (name, position, age, country, status) values
  ('Test Player One', 'striker', 19, 'Kenya', 'approved'),
  ('Test Player Two', 'gk', 21, 'Nigeria', 'pending');
insert into scouts (name, organization, verified) values
  ('Test Scout One', 'Test Academy', true);
