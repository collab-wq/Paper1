#!/usr/bin/env python3
"""Workload chunks from the verified ZIP central-directory counts."""
import json
counts={'Bearing1_2':161,'Bearing1_3':158,'Bearing2_1':491,
        'Bearing2_2':161,'Bearing3_1':2538,'Bearing3_4':1515}
shards=[]
for bearing,count in counts.items():
    for start in range(1,count+1,100):
        shards.append({'bearing':bearing,'start':start,
                       'end':min(start+99,count)})
print(json.dumps({'include':shards},separators=(',',':')))
