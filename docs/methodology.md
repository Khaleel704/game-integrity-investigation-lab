# Methodology: Game Integrity Investigation Lab

## 1. Purpose and Scope

The Game Integrity Investigation Lab demonstrates a repeatable workflow
for investigating potentially suspicious gameplay behavior using
synthetic multiplayer-game telemetry.

The project focuses on five analyst tasks:

1.  Profile player behavior across matches.
2.  Investigate anomalous gameplay signals using SQL.
3.  Correlate player statistics, event-level behavior, and detection
    alerts.
4.  Evaluate a rule-based detector against synthetic evaluation labels.
5.  Document uncertainty, limitations, and appropriate next steps.

The objective is to identify cases that may warrant further human
review---not to automatically determine that a player cheated.

**Data provenance:** All data in this project is synthetic and generated
for this lab. It is not proprietary telemetry and is not affiliated with
Sony Interactive Entertainment or PlayStation.

## 2. Research Questions

This investigation is organized around the following questions:

-   Which combinations of gameplay statistics and event-level signals
    identify players labeled as suspicious in the synthetic dataset?
-   What evidence can an analyst assemble to explain why a player was
    flagged?
-   Which cases does the baseline detector miss, and why?
-   Does an exploratory event-level detector improve recall, and what
    trade-off does it make in false positives?
-   How should detector results be communicated without overstating what
    the data proves?

## 3. Dataset and Data Model

The generated dataset contains approximately:

  Entity               Records
  ------------------ ---------
  Players                  500
  Matches                4,650
  Match statistics       4,650
  Gameplay events       25,541
  Detection alerts         201

Exact counts may vary if the data generator or random seed changes.

The principal entities are:

-   **Players:** player-level identifiers and profile attributes.
-   **Matches:** match participation and match context.
-   **Match statistics:** per-match measures such as accuracy, headshot
    rate, median reaction time, and movement speed.
-   **Gameplay events:** event-level observations, including event type,
    reaction time, and movement speed.
-   **Detection alerts:** generated alerts, their categories,
    timestamps, and risk scores.
-   **Synthetic ground truth:** the label assigned by the generator for
    detector evaluation.

The player identifier connects player-level records. Match identifiers
connect match records to match statistics. Gameplay events and alerts
are associated with players. The ground-truth table supplies the
evaluation label.

Before analysis, verify that the CSVs have been imported correctly,
identifiers join as expected, and the number of records is consistent
with the generated dataset. In particular, confirm that joins do not
multiply match-stat rows or alert counts.

## 4. Data Preparation and Quality Checks

The workflow uses Python to generate the synthetic dataset and
SQLite/SQL to investigate it. The generated CSV files are loaded into a
database using the schema in `sql/schema.sql`.

Recommended validation checks include:

-   Confirm expected tables and columns exist.
-   Check for null or malformed identifiers.
-   Confirm that match-stat records join to the intended matches.
-   Check for duplicate records where uniqueness is expected.
-   Review ranges and distributions for accuracy, headshot rate,
    reaction time, and movement speed.
-   Confirm that every player used for evaluation has a synthetic
    ground-truth label.
-   Check whether missing event or alert records are interpreted as zero
    observations rather than omitted players.

The project should preserve the original generated data when
experimenting. If a detector or preprocessing step changes, record that
change so results can be reproduced.

## 5. Investigation Workflow

### 5.1 Player Behavior Summary

Aggregate match-level statistics by player to establish a baseline
profile. Review match count, average accuracy, average headshot rate,
and average median reaction time.

The purpose is to identify unusual combinations of signals, not to treat
any one statistic as proof of misconduct. Players with more matches may
also have more opportunities to generate alerts or unusual events, so
exposure should be considered when interpreting counts.

### 5.2 Ranked Versus Non-Ranked Performance

Compare performance across match contexts where the available data
supports that distinction. The goal is to understand whether the same
player behaves differently across contexts and whether context could
explain an apparent anomaly.

A context comparison is descriptive unless a more rigorous design
supports causal conclusions.

### 5.3 Short Reaction-Time Analysis

Examine unusually short reaction times, including shot events below the
exploratory threshold used in the event-level detector.

Reaction-time observations can be affected by event definitions,
measurement design, latency, sampling, and synthetic generation rules. A
short recorded interval should therefore be treated as a signal for
review rather than a standalone conclusion.

### 5.4 Repeated Alert Analysis

Aggregate alert counts and alert types by player. Repeated alerts can
help prioritize a review, but alert counts are not independent evidence
when multiple alerts derive from correlated signals or the same
underlying behavior.

Where possible, inspect alert timestamps and associated matches to
determine whether alerts cluster around the same incident or recur over
time.

### 5.5 Evidence Bundle and Timeline

For a candidate player, assemble relevant match statistics, event
observations, alert categories, timestamps, and risk scores into a
concise evidence bundle.

The timeline provides temporal context and helps an analyst determine
whether signals are isolated or recurring. The bundle should separate:

-   **Observed data:** what the generated records contain.
-   **Interpretation:** why the pattern may merit attention.
-   **Uncertainty:** alternative explanations and limitations.
-   **Recommended disposition:** for this lab, escalation for further
    human review where warranted.

A risk score is not assumed to be a calibrated probability. A candidate
is not declared to be cheating solely because a threshold was crossed.

## 6. Baseline Detector

The baseline detector aggregates match statistics and alert counts by
player. A player is flagged only when all of the following conditions
are met:

  Condition                             Threshold
  ------------------------------ ----------------
  Number of matches                    At least 5
  Average accuracy                  At least 0.56
  Average headshot rate             At least 0.45
  Average median reaction time     At most 190 ms
  Number of detection alerts           At least 2

This is a conjunctive rule: every condition must pass. The rule is
intentionally simple and interpretable, but it can miss cases where one
aggregate metric falls outside a threshold despite suspicious
event-level behavior.

These thresholds are exploratory choices for the synthetic dataset. They
are not derived from validated real-world game telemetry.

## 7. Event-Level Detector Experiment

The exploratory event-level detector evaluates counts of specific
behaviors rather than relying on the same aggregate accuracy and
headshot-rate thresholds.

A player is flagged when all of the following conditions are met:

  Condition                                         Threshold
  --------------------------------------------- -------------
  Number of matches                                At least 5
  Number of detection alerts                       At least 2
  Shot events with reaction time below 120 ms     At least 10
  Events with movement speed above 1.25           At least 10

This experiment was motivated by analysis of baseline false negatives:
some synthetic cheating-labeled players did not meet the baseline's
accuracy or headshot-rate thresholds, even though their event-level
counts showed unusually short reaction times or elevated movement-speed
observations.

The event-level thresholds are also exploratory. Because this rule uses
event counts, players with more recorded events may have more
opportunities to cross the thresholds. A more robust future version
could normalize event counts by total relevant events, compare rates
across players, and evaluate whether the thresholds generalize to new
synthetic samples.

## 8. Detector Evaluation

The detectors are compared with the `synthetic_ground_truth` table. In
this project, the label is assigned by the data generator; it is not the
result of an independent human investigation.

The confusion-matrix outcomes are defined as:

-   **True positive (TP):** a player labeled `cheating` is flagged.
-   **False positive (FP):** a player labeled `legitimate` is flagged.
-   **False negative (FN):** a player labeled `cheating` is not flagged.
-   **True negative (TN):** a player labeled `legitimate` is not
    flagged.

The principal metrics are:

  -----------------------------------------------------------------------
  Metric                  Definition              Interpretation
  ----------------------- ----------------------- -----------------------
  Precision               TP / (TP + FP)          Share of flagged
                                                  players with the
                                                  synthetic `cheating`
                                                  label

  Recall                  TP / (TP + FN)          Share of synthetic
                                                  `cheating`-labeled
                                                  players flagged

  Specificity             TN / (TN + FP)          Share of synthetic
                                                  `legitimate` players
                                                  not flagged

  False-positive rate     FP / (FP + TN)          Share of synthetic
                                                  `legitimate` players
                                                  incorrectly flagged

  F1 score                2TP / (2TP + FP + FN)   Harmonic mean of
                                                  precision and recall

  Accuracy                (TP + TN) / (TP + FP +  Overall share of
                          FN + TN)                correct classifications
  -----------------------------------------------------------------------

Metrics should be reported for the full player population, not only for
the suspicious-labeled subset. In particular, a recall improvement does
not establish that a detector is better if its false-positive rate rises
substantially.

When a denominator is zero, the corresponding metric is undefined; the
SQL evaluation uses `NULLIF` to avoid division-by-zero errors.

### 8.1 Baseline Results

The initial baseline evaluation produced:

  Metric                         Result
  --------------------- ---------------
  True positives                      8
  False positives                     0
  False negatives                     4
  True negatives                    488
  Precision                1.000 (100%)
  Recall                  0.667 (66.7%)
  False-positive rate        0.000 (0%)

These results apply to the current synthetic dataset and detector
thresholds only. The zero observed false-positive count does not prove
that the detector would have a zero false-positive rate on real gameplay
data or on a different generated sample.

### 8.2 Preliminary Event-Level Findings

In an earlier comparison restricted to the 12 synthetic cheating-labeled
players, the event-level detector flagged 10 and missed 2, compared with
8 flagged and 4 missed by the baseline. That corresponds to recall of
83.3% versus 66.7% within that subset.

**This subset comparison is not a complete detector evaluation.** It
does not establish the event-level detector's false-positive count among
legitimate players. The full confusion matrix and all metrics must be
calculated across all 500 players before drawing conclusions about the
overall trade-off.

## 9. False-Negative Analysis

False negatives are reviewed to understand how the detector's conditions
interact and which signals it excludes.

In the initial baseline analysis, the four false negatives did not meet
the average accuracy threshold, the average headshot-rate threshold, or
both. Three also had average reaction times above 190 ms, while one was
near the threshold. This showed that the conjunctive baseline rule could
exclude players even when other signals were unusual.

The event-level experiment was designed to test whether event counts
could identify some of those missed cases. Its outcome should be judged
using the full population evaluation, not only by the number of
additional suspicious-labeled players detected.

A false negative in this project means only that the rule did not flag a
player carrying the generator's `cheating` label. It is not evidence
that a real-world cheating incident went undetected.

## 10. Interpretation and Decision Standard

The project uses a cautious investigative standard:

1.  Identify a pattern that differs from the expected synthetic
    baseline.
2.  Correlate multiple observations where possible.
3.  Review event timing and alert context.
4.  Check whether the conclusion depends heavily on a single threshold.
5.  Document alternative explanations and data limitations.
6.  Recommend human review rather than making a definitive accusation.

Signals may be correlated. For example, an alert and an event-level
anomaly may both derive from the same underlying synthetic behavior.
They should not automatically be treated as independent corroboration.

## 11. Limitations and Threats to Validity

-   **Synthetic data:** the dataset does not represent production
    gameplay telemetry or real player populations.
-   **Generator-defined labels:** labels are assigned during data
    generation and are not independently verified.
-   **Injected patterns:** some synthetic suspicious profiles are
    designed to be more subtle and overlap with legitimate behavior.
-   **Exploratory thresholds:** thresholds were chosen for this lab and
    have not been calibrated on representative real-world data.
-   **Correlated signals:** match statistics, event observations, and
    alerts may reflect the same underlying pattern.
-   **Exposure effects:** event and alert counts may increase with the
    number of matches or events observed.
-   **Sample dependence:** results from one generated dataset may not
    generalize to another random sample.
-   **Incomplete event-level validation until full evaluation:**
    event-level recall among suspicious-labeled players is insufficient
    without false-positive and full-population metrics.
-   **No causal claim:** the analysis identifies patterns associated
    with synthetic labels; it does not prove intent or causation.
-   **No operational deployment:** this is a portfolio lab, not a
    production anti-cheat system.

## 12. Reproducibility and Project Artifacts

The repository is intended to include:

-   Python code to generate the synthetic dataset.
-   SQL schema and investigative queries.
-   SQL evaluation for the baseline and event-level detectors.
-   Generated CSV data.
-   Analytical visualizations.
-   A final investigation report.

Run commands from the repository root and follow the README for the
exact setup. If scripts or folders are moved, update paths and confirm
the workflow still runs from a clean environment.

For a reproducible evaluation, record the generator version, random seed
(if configured), dataset record counts, detector thresholds, and
evaluation output. When changing thresholds, preserve the prior results
so the comparison remains transparent.

## 13. Next Steps

Potential improvements include:

1.  Complete the event-level detector's full 500-player confusion
    matrix.
2.  Compare precision, recall, specificity, false-positive rate, F1
    score, and accuracy for both detectors.
3.  Review every event-level false positive to understand which
    legitimate profiles trigger the rule.
4.  Normalize event counts by relevant event totals and compare
    rate-based thresholds.
5.  Repeat the experiment across multiple generated samples or fixed
    random seeds.
6.  Perform threshold sensitivity analysis rather than relying on a
    single cutoff.
7.  Add distribution plots and subgroup comparisons to assess overlap
    between synthetic labels.
8.  Document the final results and explicitly distinguish measured
    findings from hypotheses.

## Summary

This lab demonstrates an interpretable security investigation workflow:
profile behavior, correlate telemetry and alerts, assemble evidence,
evaluate detection rules, investigate false negatives, and document
uncertainty. Its strongest contribution is not a claim of
production-grade cheating detection, but a transparent demonstration of
how an analyst can evaluate behavioral signals and communicate the
limits of the evidence.
