"""Evaluate an illustrative behavior-based detector against synthetic labels.

This is a learning demo, not a production anti-cheat detector. All data is synthetic.
Run: python evaluate_detector.py
"""
import csv, os, sqlite3
from collections import defaultdict
ROOT=os.path.dirname(os.path.abspath(__file__))
DATA=os.path.join(ROOT,'data')
DB=os.path.join(ROOT,'game_integrity_lab.sqlite')

def rows(filename):
    with open(os.path.join(DATA,filename),newline='',encoding='utf-8') as f:
        return list(csv.DictReader(f))

def main():
    if os.path.exists(DB): os.remove(DB)
    con=sqlite3.connect(DB)
    schema=open(os.path.join(ROOT,'sql','schema.sql'),encoding='utf-8').read()
    con.executescript(schema)
    tables={
      'players':'players.csv','matches':'matches.csv','player_match_stats':'player_match_stats.csv',
      'gameplay_events':'gameplay_events.csv','detection_alerts':'detection_alerts.csv',
      'synthetic_ground_truth':'synthetic_ground_truth.csv'}
    for table,file in tables.items():
        data=rows(file)
        if not data: continue
        cols=list(data[0].keys())
        placeholders=','.join('?' for _ in cols)
        sql=f"INSERT INTO {table} ({','.join(cols)}) VALUES ({placeholders})"
        con.executemany(sql,[[r[c] if r[c] != '' else None for c in cols] for r in data])
    con.commit()
    # Transparent illustrative rule: combine sustained elevated accuracy/headshot rate,
    # unusually low reaction time, and repeated alerts. Thresholds are deliberately explicit.
    query='''
    WITH stats AS (
      SELECT player_id, COUNT(*) n_matches, AVG(accuracy) acc, AVG(headshot_rate) hs,
             AVG(median_reaction_ms) reaction, AVG(avg_movement_speed) speed
      FROM player_match_stats GROUP BY player_id
    ), alerts AS (
      SELECT player_id, COUNT(*) alert_count, COUNT(DISTINCT alert_type) alert_types,
             MAX(risk_score) max_score FROM detection_alerts GROUP BY player_id
    ), scored AS (
      SELECT s.player_id, s.n_matches, s.acc, s.hs, s.reaction, s.speed,
             COALESCE(a.alert_count,0) alert_count, COALESCE(a.alert_types,0) alert_types,
             COALESCE(a.max_score,0) max_score,
             CASE WHEN s.n_matches >= 5 AND s.acc >= 0.56 AND s.hs >= 0.45
                        AND s.reaction <= 190 AND COALESCE(a.alert_count,0) >= 2
                  THEN 1 ELSE 0 END AS flagged
      FROM stats s LEFT JOIN alerts a USING(player_id)
    )
    SELECT g.synthetic_label, s.flagged FROM scored s
    JOIN synthetic_ground_truth g USING(player_id)
    '''
    results=con.execute(query).fetchall()
    tp=sum(1 for label,pred in results if label=='cheating' and pred==1)
    fp=sum(1 for label,pred in results if label=='legitimate' and pred==1)
    fn=sum(1 for label,pred in results if label=='cheating' and pred==0)
    tn=sum(1 for label,pred in results if label=='legitimate' and pred==0)
    precision=tp/(tp+fp) if tp+fp else 0
    recall=tp/(tp+fn) if tp+fn else 0
    fpr=fp/(fp+tn) if fp+tn else 0
    print('SYNTHETIC GAME-INTEGRITY DETECTOR EVALUATION')
    print('Rule: >=5 matches, avg accuracy >=0.56, avg headshot rate >=0.45, avg reaction <=190ms, >=2 alerts')
    print(f'TP={tp} FP={fp} FN={fn} TN={tn}')
    print(f'Precision={precision:.3f} | Recall={recall:.3f} | False-positive rate={fpr:.3f}')
    print('\nImportant: metrics only measure performance against injected synthetic labels and this toy dataset. They do not establish real-world anti-cheat accuracy.')
    con.close()

if __name__=='__main__': main()
