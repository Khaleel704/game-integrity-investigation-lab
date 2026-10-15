import csv, random, os, math
from datetime import datetime, timedelta

random.seed(42)
ROOT=os.path.dirname(os.path.abspath(__file__))
DATA=os.path.join(ROOT,'data')
os.makedirs(DATA,exist_ok=True)

def write_csv(name, rows, fields):
    with open(os.path.join(DATA,name),'w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(rows)

# Entirely synthetic data for portfolio/demo use. No real player data.
players=[]
for i in range(1,501):
    pid=f'P{i:04d}'
    players.append({'player_id':pid,'account_age_days':random.randint(5,2200),'region':random.choice(['NA','EU','APAC','LATAM']),'platform':random.choice(['PC','Console A','Console B']),'account_status':'active'})
write_csv('players.csv',players,list(players[0]))

cheaters=set(random.sample([p['player_id'] for p in players],12))
subtle_cheaters=set(random.sample(sorted(cheaters),4))
legit_pool=[p['player_id'] for p in players if p['player_id'] not in cheaters]
skilled_legit=set(random.sample(legit_pool,12))
start=datetime(2026,1,1)
matches=[]; stats=[]; events=[]; alerts=[]; truth=[]
event_id=1; match_id=1; alert_id=1
for p in players:
    pid=p['player_id']; suspicious=pid in cheaters
    # Ground truth is synthetic and only for evaluating the demonstration detector.
    truth.append({'player_id':pid,'synthetic_label':'cheating' if suspicious else 'legitimate','label_note':'Injected synthetic pattern for detector evaluation' if suspicious else 'Baseline synthetic player'})
    n_matches=random.randint(5,14)
    for j in range(n_matches):
        mid=f'M{match_id:06d}'; match_id+=1
        ts=start+timedelta(days=random.randint(0,270),minutes=random.randint(0,1439))
        duration=max(240,int(random.gauss(720,180)))
        mode=random.choice(['ranked','casual','arena'])
        matches.append({'match_id':mid,'started_at':ts.isoformat(timespec='seconds'),'game_mode':mode,'duration_seconds':duration,'region':p['region']})
        # baseline stats; injected suspicious players have elevated accuracy/headshot rates but some overlap remains
        if suspicious and pid not in subtle_cheaters:
            accuracy=min(0.98,max(0.15,random.gauss(0.69,0.09)))
            headshot=min(0.95,max(0.05,random.gauss(0.62,0.12)))
            reaction=max(65,random.gauss(145,28))
            speed=max(1.0,random.gauss(1.32,0.12))
        elif suspicious:  # subtle injected cases intentionally overlap with legitimate behavior
            accuracy=min(0.86,max(0.12,random.gauss(0.51,0.12)))
            headshot=min(0.82,max(0.03,random.gauss(0.40,0.13)))
            reaction=max(75,random.gauss(190,42))
            speed=max(0.75,random.gauss(1.13,0.12))
        elif pid in skilled_legit:  # legitimate high-skill accounts help expose false positives
            accuracy=min(0.86,max(0.12,random.gauss(0.50,0.10)))
            headshot=min(0.85,max(0.03,random.gauss(0.39,0.12)))
            reaction=max(85,random.gauss(225,42))
            speed=max(0.7,random.gauss(1.05,0.09))
        else:
            accuracy=min(0.78,max(0.08,random.gauss(0.34,0.11)))
            headshot=min(0.72,max(0.02,random.gauss(0.24,0.10)))
            reaction=max(90,random.gauss(265,55))
            speed=max(0.65,random.gauss(1.0,0.08))
        shots=random.randint(25,150); hits=min(shots,round(shots*accuracy)); kills=max(0,round(random.gauss(8 if suspicious else 5,2)))
        stats.append({'match_id':mid,'player_id':pid,'kills':kills,'deaths':random.randint(0,12),'shots_fired':shots,'shots_hit':hits,'accuracy':round(hits/shots,4),'headshot_rate':round(headshot,4),'median_reaction_ms':round(reaction,1),'avg_movement_speed':round(speed,3),'ranked_mode':1 if mode=='ranked' else 0})
        # 3-8 events per match. Suspicious users have more unusually short reaction events and speed anomalies.
        for k in range(random.randint(3,8)):
            etime=ts+timedelta(seconds=random.randint(0,duration))
            if suspicious and random.random()<0.45:
                etype='shot'; reaction_ms=round(max(35,random.gauss(105,18)),1); movement=round(random.gauss(1.34,0.08),3); target_dist=round(random.uniform(15,90),1)
            else:
                etype=random.choice(['shot','movement','reload','objective']); reaction_ms=round(max(90,random.gauss(270,60)),1); movement=round(max(0.6,random.gauss(1.0,0.08)),3); target_dist=round(random.uniform(3,70),1)
            events.append({'event_id':f'E{event_id:08d}','match_id':mid,'player_id':pid,'event_time':etime.isoformat(timespec='seconds'),'event_type':etype,'reaction_ms':reaction_ms if etype=='shot' else '', 'movement_speed':movement,'target_distance_m':target_dist if etype=='shot' else ''})
            event_id+=1
        # A noisy alert system: some injected cheaters flagged, some legit false positives.
        prob=(0.68 if pid not in subtle_cheaters else 0.34) if suspicious else (0.12 if pid in skilled_legit else 0.025)
        if random.random()<prob:
            score=round(random.uniform(0.72,0.99) if suspicious else random.uniform(0.55,0.86),3)
            alerts.append({'alert_id':f'A{alert_id:06d}','player_id':pid,'match_id':mid,'alert_type':random.choice(['aim_pattern','reaction_anomaly','movement_anomaly']),'risk_score':score,'created_at':(ts+timedelta(seconds=duration+random.randint(0,1800))).isoformat(timespec='seconds'),'status':'new'})
            alert_id+=1
write_csv('matches.csv',matches,list(matches[0]))
write_csv('player_match_stats.csv',stats,list(stats[0]))
write_csv('gameplay_events.csv',events,list(events[0]))
write_csv('detection_alerts.csv',alerts,list(alerts[0]))
write_csv('synthetic_ground_truth.csv',truth,list(truth[0]))
print(f'Generated {len(players)} players, {len(matches)} matches, {len(stats)} stat rows, {len(events)} events, {len(alerts)} alerts.')
