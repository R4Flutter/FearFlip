-- The Long Night (plans/11 v2): each player's best verified run of each week.
CREATE TABLE runs (
	week INTEGER NOT NULL,
	player TEXT NOT NULL,             -- CrazyGames userId, from the verified token
	name TEXT NOT NULL,               -- CrazyGames username when the best was set
	ms INTEGER NOT NULL,              -- the best time
	splits TEXT NOT NULL,             -- JSON: race seconds at each key
	tape TEXT NOT NULL,               -- base64 float32 x, z, yaw every 0.2 s (RaceGhost samples): the rival ghost
	at TEXT NOT NULL,                 -- ISO time it arrived: its timestamp on the CrazyGames board
	sent INTEGER NOT NULL DEFAULT 0,  -- 0 waiting for CrazyGames, 1 on its board, 2 refused there for good
	PRIMARY KEY (week, player)
);
CREATE INDEX runs_board ON runs (week, ms);
-- The cron's resend reads only the bests CrazyGames hasn't taken.
CREATE INDEX runs_unsent ON runs (week) WHERE sent = 0;
