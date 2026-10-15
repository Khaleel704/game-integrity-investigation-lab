-- SQLite schema for Game Integrity Investigation Lab.
-- All data is synthetic and created for this portfolio project.
CREATE TABLE IF NOT EXISTS players (
  player_id TEXT PRIMARY KEY, account_age_days INTEGER, region TEXT, platform TEXT, account_status TEXT
);
CREATE TABLE IF NOT EXISTS matches (
  match_id TEXT PRIMARY KEY, started_at TEXT, game_mode TEXT, duration_seconds INTEGER, region TEXT
);
CREATE TABLE IF NOT EXISTS player_match_stats (
  match_id TEXT, player_id TEXT, kills INTEGER, deaths INTEGER, shots_fired INTEGER, shots_hit INTEGER,
  accuracy REAL, headshot_rate REAL, median_reaction_ms REAL, avg_movement_speed REAL, ranked_mode INTEGER
);
CREATE TABLE IF NOT EXISTS gameplay_events (
  event_id TEXT PRIMARY KEY, match_id TEXT, player_id TEXT, event_time TEXT, event_type TEXT,
  reaction_ms REAL, movement_speed REAL, target_distance_m REAL
);
CREATE TABLE IF NOT EXISTS detection_alerts (
  alert_id TEXT PRIMARY KEY, player_id TEXT, match_id TEXT, alert_type TEXT, risk_score REAL, created_at TEXT, status TEXT
);
CREATE TABLE IF NOT EXISTS synthetic_ground_truth (
  player_id TEXT PRIMARY KEY, synthetic_label TEXT, label_note TEXT
);
