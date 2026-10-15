-- ============================================================
-- Game Integrity Investigation Lab
-- Event-Level Detector Evaluation
-- ============================================================
--
-- Purpose:
-- Evaluate the event-level detector against synthetic
-- ground-truth labels across the complete player population.
--
-- Event-level detector criteria:
--   1. At least 5 matches
--   2. At least 2 detection alerts
--   3. At least 10 shots with reaction time below 120 ms
--   4. At least 10 events with movement speed above 1.25
--
-- Baseline detector criteria:
--   1. At least 5 matches
--   2. Average accuracy >= 0.56
--   3. Average headshot rate >= 0.45
--   4. Average reaction time <= 190 ms
--   5. At least 2 detection alerts
--
-- IMPORTANT:
-- These are exploratory thresholds for synthetic data.
-- They are not validated real-world anti-cheat thresholds.
-- ============================================================


-- ============================================================
-- 1. Aggregate player-level gameplay statistics
-- ============================================================

DROP TABLE IF EXISTS temp.player_metrics;

CREATE TEMP TABLE player_metrics AS
SELECT
    p.player_id,

    COUNT(DISTINCT m.match_id) AS n_matches,

    AVG(s.accuracy) AS avg_accuracy,

    AVG(s.headshot_rate) AS avg_headshot_rate,

    AVG(s.median_reaction_ms) AS avg_reaction_ms

FROM players p

LEFT JOIN matches m
    ON p.player_id = m.player_id

LEFT JOIN match_stats s
    ON m.match_id = s.match_id

GROUP BY
    p.player_id;


-- ============================================================
-- 2. Aggregate detection alerts
-- ============================================================

DROP TABLE IF EXISTS temp.player_alerts;

CREATE TEMP TABLE player_alerts AS
SELECT
    p.player_id,

    COUNT(a.alert_id) AS alert_count,

    MAX(a.risk_score) AS max_risk_score

FROM players p

LEFT JOIN detection_alerts a
    ON p.player_id = a.player_id

GROUP BY
    p.player_id;


-- ============================================================
-- 3. Aggregate event-level behavioral signals
-- ============================================================

DROP TABLE IF EXISTS temp.player_event_metrics;

CREATE TEMP TABLE player_event_metrics AS
SELECT
    p.player_id,

    COUNT(e.event_id) AS total_events,

    SUM(
        CASE
            WHEN LOWER(e.event_type) = 'shot'
             AND e.reaction_ms < 120
            THEN 1
            ELSE 0
        END
    ) AS short_reaction_shots,

    SUM(
        CASE
            WHEN e.movement_speed > 1.25
            THEN 1
            ELSE 0
        END
    ) AS high_speed_events,

    AVG(e.reaction_ms) AS avg_event_reaction_ms,

    AVG(e.movement_speed) AS avg_event_movement_speed

FROM players p

LEFT JOIN gameplay_events e
    ON p.player_id = e.player_id

GROUP BY
    p.player_id;


-- ============================================================
-- 4. Generate baseline and event-level predictions
-- ============================================================

DROP TABLE IF EXISTS temp.detector_predictions;

CREATE TEMP TABLE detector_predictions AS
SELECT
    p.player_id,

    g.synthetic_label,

    COALESCE(pm.n_matches, 0) AS n_matches,

    COALESCE(pa.alert_count, 0) AS alert_count,

    COALESCE(em.short_reaction_shots, 0)
        AS short_reaction_shots,

    COALESCE(em.high_speed_events, 0)
        AS high_speed_events,

    pm.avg_accuracy,

    pm.avg_headshot_rate,

    pm.avg_reaction_ms,

    CASE
        WHEN COALESCE(pm.n_matches, 0) >= 5
         AND pm.avg_accuracy >= 0.56
         AND pm.avg_headshot_rate >= 0.45
         AND pm.avg_reaction_ms <= 190
         AND COALESCE(pa.alert_count, 0) >= 2
        THEN 1
        ELSE 0
    END AS baseline_flagged,

    CASE
        WHEN COALESCE(pm.n_matches, 0) >= 5
         AND COALESCE(pa.alert_count, 0) >= 2
         AND COALESCE(em.short_reaction_shots, 0) >= 10
         AND COALESCE(em.high_speed_events, 0) >= 10
        THEN 1
        ELSE 0
    END AS event_flagged

FROM players p

LEFT JOIN player_metrics pm
    ON p.player_id = pm.player_id

LEFT JOIN player_alerts pa
    ON p.player_id = pa.player_id

LEFT JOIN player_event_metrics em
    ON p.player_id = em.player_id

LEFT JOIN synthetic_ground_truth g
    ON p.player_id = g.player_id;


-- ============================================================
-- 5. Full confusion matrix: baseline detector
-- ============================================================

SELECT
    'Baseline Detector' AS detector,

    SUM(
        CASE
            WHEN synthetic_label = 'cheating'
             AND baseline_flagged = 1
            THEN 1 ELSE 0
        END
    ) AS true_positives,

    SUM(
        CASE
            WHEN synthetic_label = 'legitimate'
             AND baseline_flagged = 1
            THEN 1 ELSE 0
        END
    ) AS false_positives,

    SUM(
        CASE
            WHEN synthetic_label = 'cheating'
             AND baseline_flagged = 0
            THEN 1 ELSE 0
        END
    ) AS false_negatives,

    SUM(
        CASE
            WHEN synthetic_label = 'legitimate'
             AND baseline_flagged = 0
            THEN 1 ELSE 0
        END
    ) AS true_negatives

FROM detector_predictions;


-- ============================================================
-- 6. Full confusion matrix: event-level detector
-- ============================================================

SELECT
    'Event-Level Detector' AS detector,

    SUM(
        CASE
            WHEN synthetic_label = 'cheating'
             AND event_flagged = 1
            THEN 1 ELSE 0
        END
    ) AS true_positives,

    SUM(
        CASE
            WHEN synthetic_label = 'legitimate'
             AND event_flagged = 1
            THEN 1 ELSE 0
        END
    ) AS false_positives,

    SUM(
        CASE
            WHEN synthetic_label = 'cheating'
             AND event_flagged = 0
            THEN 1 ELSE 0
        END
    ) AS false_negatives,

    SUM(
        CASE
            WHEN synthetic_label = 'legitimate'
             AND event_flagged = 0
            THEN 1 ELSE 0
        END
    ) AS true_negatives

FROM detector_predictions;


-- ============================================================
-- 7. Calculate evaluation metrics for both detectors
-- ============================================================

WITH confusion_matrices AS (

    SELECT
        'Baseline Detector' AS detector,

        SUM(
            CASE
                WHEN synthetic_label = 'cheating'
                 AND baseline_flagged = 1
                THEN 1 ELSE 0
            END
        ) AS tp,

        SUM(
            CASE
                WHEN synthetic_label = 'legitimate'
                 AND baseline_flagged = 1
                THEN 1 ELSE 0
            END
        ) AS fp,

        SUM(
            CASE
                WHEN synthetic_label = 'cheating'
                 AND baseline_flagged = 0
                THEN 1 ELSE 0
            END
        ) AS fn,

        SUM(
            CASE
                WHEN synthetic_label = 'legitimate'
                 AND baseline_flagged = 0
                THEN 1 ELSE 0
            END
        ) AS tn

    FROM detector_predictions

    UNION ALL

    SELECT
        'Event-Level Detector' AS detector,

        SUM(
            CASE
                WHEN synthetic_label = 'cheating'
                 AND event_flagged = 1
                THEN 1 ELSE 0
            END
        ) AS tp,

        SUM(
            CASE
                WHEN synthetic_label = 'legitimate'
                 AND event_flagged = 1
                THEN 1 ELSE 0
            END
        ) AS fp,

        SUM(
            CASE
                WHEN synthetic_label = 'cheating'
                 AND event_flagged = 0
                THEN 1 ELSE 0
            END
        ) AS fn,

        SUM(
            CASE
                WHEN synthetic_label = 'legitimate'
                 AND event_flagged = 0
                THEN 1 ELSE 0
            END
        ) AS tn

    FROM detector_predictions
)

SELECT
    detector,

    tp AS true_positives,
    fp AS false_positives,
    fn AS false_negatives,
    tn AS true_negatives,

    ROUND(
        1.0 * tp / NULLIF(tp + fp, 0),
        4
    ) AS precision,

    ROUND(
        1.0 * tp / NULLIF(tp + fn, 0),
        4
    ) AS recall,

    ROUND(
        1.0 * tn / NULLIF(tn + fp, 0),
        4
    ) AS specificity,

    ROUND(
        1.0 * fp / NULLIF(fp + tn, 0),
        4
    ) AS false_positive_rate,

    ROUND(
        2.0 * tp / NULLIF(2 * tp + fp + fn, 0),
        4
    ) AS f1_score,

    ROUND(
        1.0 * (tp + tn) /
        NULLIF(tp + fp + fn + tn, 0),
        4
    ) AS accuracy

FROM confusion_matrices;


-- ============================================================
-- 8. Identify cases where detector outcomes differ
-- ============================================================

SELECT
    player_id,

    synthetic_label,

    baseline_flagged,

    event_flagged,

    CASE
        WHEN baseline_flagged = 1
         AND event_flagged = 1
        THEN 'Flagged by both'

        WHEN baseline_flagged = 1
         AND event_flagged = 0
        THEN 'Baseline only'

        WHEN baseline_flagged = 0
         AND event_flagged = 1
        THEN 'Event-level only'

        ELSE 'Missed by both'
    END AS detector_outcome,

    n_matches,

    alert_count,

    short_reaction_shots,

    high_speed_events,

    ROUND(avg_accuracy, 4) AS avg_accuracy,

    ROUND(avg_headshot_rate, 4) AS avg_headshot_rate,

    ROUND(avg_reaction_ms, 2) AS avg_reaction_ms

FROM detector_predictions

WHERE baseline_flagged <> event_flagged

ORDER BY
    synthetic_label,
    detector_outcome,
    player_id;


-- ============================================================
-- 9. Summarize outcome changes by ground-truth label
-- ============================================================

SELECT
    synthetic_label,

    CASE
        WHEN baseline_flagged = 1
         AND event_flagged = 1
        THEN 'Flagged by both'

        WHEN baseline_flagged = 1
         AND event_flagged = 0
        THEN 'Baseline only'

        WHEN baseline_flagged = 0
         AND event_flagged = 1
        THEN 'Event-level only'

        ELSE 'Missed by both'
    END AS detector_outcome,

    COUNT(*) AS player_count

FROM detector_predictions

GROUP BY
    synthetic_label,
    detector_outcome

ORDER BY
    synthetic_label,
    detector_outcome;