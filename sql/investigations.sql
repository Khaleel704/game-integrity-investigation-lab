-- Investigation 1: summarize player behavior over enough matches to reduce small-sample noise.
-- Treat these as leads for human review, not proof of cheating.
SELECT player_id, COUNT(*) AS matches_observed,
       ROUND(AVG(accuracy), 3) AS avg_accuracy,
       ROUND(AVG(headshot_rate), 3) AS avg_headshot_rate,
       ROUND(AVG(median_reaction_ms), 1) AS avg_reaction_ms,
       ROUND(AVG(avg_movement_speed), 3) AS avg_movement_speed
FROM player_match_stats
GROUP BY player_id
HAVING COUNT(*) >= 5
ORDER BY avg_accuracy DESC, avg_headshot_rate DESC;

-- Investigation 2: compare ranked-mode accuracy with the player's own non-ranked baseline.
WITH mode_rates AS (
  SELECT player_id,
         AVG(CASE WHEN ranked_mode = 1 THEN accuracy END) AS ranked_accuracy,
         AVG(CASE WHEN ranked_mode = 0 THEN accuracy END) AS other_accuracy,
         SUM(CASE WHEN ranked_mode = 1 THEN 1 ELSE 0 END) AS ranked_matches,
         SUM(CASE WHEN ranked_mode = 0 THEN 1 ELSE 0 END) AS other_matches
  FROM player_match_stats GROUP BY player_id
)
SELECT player_id, ranked_matches, other_matches,
       ROUND(ranked_accuracy,3) AS ranked_accuracy,
       ROUND(other_accuracy,3) AS other_accuracy,
       ROUND(ranked_accuracy - other_accuracy,3) AS accuracy_gap
FROM mode_rates
WHERE ranked_matches >= 5 AND other_matches >= 5
ORDER BY accuracy_gap DESC;

-- Investigation 3: identify players with repeated very short shot reaction events.
-- Threshold is illustrative and should be calibrated to game mechanics and telemetry quality.
SELECT player_id, COUNT(*) AS shot_events,
       ROUND(AVG(reaction_ms),1) AS mean_reaction_ms,
       ROUND(AVG(CASE WHEN reaction_ms < 120 THEN 1.0 ELSE 0.0 END),3) AS share_under_120ms
FROM gameplay_events
WHERE event_type = 'shot' AND reaction_ms IS NOT NULL
GROUP BY player_id
HAVING COUNT(*) >= 10
ORDER BY share_under_120ms DESC, shot_events DESC;

-- Investigation 4: summarize alerts and avoid treating one alert as a verdict.
SELECT a.player_id, COUNT(*) AS alert_count,
       ROUND(MAX(a.risk_score),3) AS max_risk_score,
       COUNT(DISTINCT a.alert_type) AS distinct_alert_types,
       COUNT(DISTINCT a.match_id) AS matches_with_alerts
FROM detection_alerts a
GROUP BY a.player_id
HAVING COUNT(*) >= 2
ORDER BY distinct_alert_types DESC, matches_with_alerts DESC, max_risk_score DESC;

-- Investigation 5: evidence bundle for a candidate account. Replace P0001 with the candidate under review.
SELECT s.player_id, s.match_id, m.started_at, m.game_mode, s.kills, s.deaths,
       s.shots_fired, s.shots_hit, s.accuracy, s.headshot_rate,
       s.median_reaction_ms, s.avg_movement_speed
FROM player_match_stats s JOIN matches m ON m.match_id = s.match_id
WHERE s.player_id = 'P0428'
ORDER BY m.started_at;

-- Investigation 6: candidate alert timeline, including evidence types and risk scores.
SELECT a.player_id, a.created_at, a.alert_type, a.risk_score, a.status, a.match_id
FROM detection_alerts a
WHERE a.player_id = 'P0428'
ORDER BY a.created_at;
