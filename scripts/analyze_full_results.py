#!/usr/bin/env python3
"""Descriptive statistics only; no threshold fitting or baseline experiment."""
import csv
import argparse
from collections import defaultdict
from pathlib import Path
import numpy as np

parser=argparse.ArgumentParser()
parser.add_argument('--root',type=Path,default=Path('.'))
args=parser.parse_args()
root=args.root
with (root/'REAL_DATA_FULL_RESULTS.csv').open() as f:
    rows=list(csv.DictReader(f))

cwru={105:('0HP','inner'),106:('1HP','inner'),107:('2HP','inner'),
      130:('0HP','outer-6'),131:('1HP','outer-6'),132:('2HP','outer-6'),
      144:('0HP','outer-3'),145:('1HP','outer-3'),146:('2HP','outer-3'),
      156:('0HP','outer-12'),158:('1HP','outer-12'),159:('2HP','outer-12')}
counts={'Bearing1_2':161,'Bearing1_3':158,'Bearing2_1':491,
        'Bearing2_2':161,'Bearing3_1':2538,'Bearing3_4':1515}

def case(row):
    dataset=row['dataset']; file=Path(row['file'])
    if dataset=='cwru': return '/'.join(cwru[int(file.stem)])
    if dataset=='paderborn': return file.parent.name
    if dataset=='ottawa': return file.stem
    bearing=file.parent.name
    fraction=int(file.stem)/counts[bearing]
    stage='early' if fraction<=1/3 else ('middle' if fraction<=2/3 else 'late')
    return bearing+'/'+stage

def val(row,key):
    try: return float(row[key])
    except (TypeError,ValueError): return float('nan')

def pct(data,p):
    data=np.array(data,dtype=float); data=data[np.isfinite(data)]
    return float(np.percentile(data,p)) if len(data) else float('nan')

def selected_band_centers(row):
    if row['status']!='SELECTED': return []
    import json
    items=json.loads(row['candidates_json'])
    matches=[item for item in items if str(item['R'])==row['selected_R']
             and item['hypothesis']==row['selected_hypothesis']]
    assert len(matches)==1
    return sorted((float(pair[0])+float(pair[1]))/2
                  for pair in matches[0]['bands_hz'])

groups=defaultdict(list)
for row in rows:
    groups[(row['dataset'],'ALL')].append(row)
    groups[(row['dataset'],case(row))].append(row)
fields=['dataset','case','windows','valid','no_valid','R2_fraction','R3_fraction',
        'R4_fraction','error_unit','error_median','error_q1','error_q3',
        'contrast_median','contrast_q1','contrast_q3',
        'Qe_median','Qe_q1','Qe_q3','Qc_median','Qc_q1','Qc_q3',
        'J_median','J_q1','J_q3',
        'lowest_band_center_median_hz','highest_band_center_median_hz',
        'posthoc_hypothesis_matches','posthoc_comparable']
with (root/'FULL_STATISTICS.csv').open('w',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
    for (dataset,name),group in sorted(groups.items()):
        valid=[r for r in group if r['status']=='SELECTED']
        error_key='error_order' if dataset=='ottawa' else 'error_hz'
        record={'dataset':dataset,'case':name,'windows':len(group),
                'valid':len(valid),'no_valid':sum(r['status']=='NO_VALID_R' for r in group),
                'error_unit':'order' if dataset=='ottawa' else 'Hz'}
        for R in (2,3,4):
            record[f'R{R}_fraction']=sum(str(r['selected_R'])==str(R) for r in group)/len(group)
        for output,key in [('error',error_key),('contrast','contrast_linear'),
                           ('Qe','location_confidence'),('Qc','contrast_utility'),('J','J')]:
            values=[val(r,key) for r in valid]
            record[output+'_median']=pct(values,50)
            record[output+'_q1']=pct(values,25)
            record[output+'_q3']=pct(values,75)
        centers=[selected_band_centers(r) for r in valid]
        record['lowest_band_center_median_hz']=pct([c[0] for c in centers],50)
        record['highest_band_center_median_hz']=pct([c[-1] for c in centers],50)
        comparable=[r for r in valid if r['true_label_for_posthoc'] in ('BPFO','BPFI')]
        record['posthoc_comparable']=len(comparable)
        record['posthoc_hypothesis_matches']=sum(
            r['selected_hypothesis']==r['true_label_for_posthoc'] for r in comparable)
        writer.writerow(record)

xjtu_pairs=defaultdict(list)
for row in rows:
    if row['dataset']=='xjtu':
        xjtu_pairs[(Path(row['file']).parent.name,Path(row['file']).stem)].append(row)
pair_groups=defaultdict(list)
for (bearing,snapshot),pair in xjtu_pairs.items():
    pair_groups[bearing].append(pair)
with (root/'XJTU_PAIR_STABILITY.csv').open('w',newline='') as f:
    fields=['bearing','snapshots_with_results','incomplete_snapshots',
            'both_selected','both_no_valid',
            'one_selected','same_R_given_both_selected',
            'same_hypothesis_given_both_selected','abs_J_difference_median']
    writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
    for bearing,pairs in sorted(pair_groups.items()):
        complete=[p for p in pairs if len(p)==2]
        both=[p for p in complete if all(r['status']=='SELECTED' for r in p)]
        writer.writerow({'bearing':bearing,'snapshots_with_results':len(pairs),
            'incomplete_snapshots':counts[bearing]-len(complete),
            'both_selected':len(both),
            'both_no_valid':sum(all(r['status']=='NO_VALID_R' for r in p) for p in complete),
            'one_selected':sum(sum(r['status']=='SELECTED' for r in p)==1 for p in complete),
            'same_R_given_both_selected':sum(p[0]['selected_R']==p[1]['selected_R'] for p in both),
            'same_hypothesis_given_both_selected':sum(
                p[0]['selected_hypothesis']==p[1]['selected_hypothesis'] for p in both),
            'abs_J_difference_median':pct(
                [abs(val(p[0],'J')-val(p[1],'J')) for p in both],50)})

# External labels enter only here, after MATLAB scoring and R selection.
import json
target_rows=[]
for row in rows:
    candidates=json.loads(row['candidates_json'])
    for target in row['true_label_for_posthoc'].split('+'):
        valid=[c for c in candidates if c['hypothesis']==target and c['valid']]
        chosen=(sorted(valid,key=lambda c:(-float(c['J']),int(c['R'])))[0]
                if valid else None)
        target_rows.append({'dataset':row['dataset'],'case':case(row),
            'file':row['file'],'start_sample':row['start_sample'],
            'target':target,'valid':bool(chosen),
            'chosen_hypothesis_matches':row['selected_hypothesis']==target,
            'best_valid_R':chosen['R'] if chosen else '',
            'J':chosen['J'] if chosen else '',
            'error':chosen.get('error_order' if row['dataset']=='ottawa' else 'error_hz','')
                     if chosen else '',
            'raw_target_peak':chosen.get('raw_target_peak_order' if row['dataset']=='ottawa'
                                         else 'raw_target_peak_hz','') if chosen else '',
            'fused_target_peak':chosen.get('target_peak_order' if row['dataset']=='ottawa'
                                           else 'target_peak_hz','') if chosen else '',
            'raw_contrast_linear':chosen.get('raw_target_contrast','') if chosen else '',
            'contrast_linear':chosen['contrast_linear'] if chosen else '',
            'retained_pixel_fraction':chosen.get('retained_pixel_fraction','') if chosen else ''})
target_fields=list(target_rows[0])
with (root/'POSTHOC_TARGET_EVIDENCE.csv').open('w',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=target_fields);writer.writeheader()
    writer.writerows(target_rows)
target_groups=defaultdict(list)
for row in target_rows:
    target_groups[(row['dataset'],'ALL',row['target'])].append(row)
    target_groups[(row['dataset'],row['case'],row['target'])].append(row)
with (root/'POSTHOC_TARGET_STATISTICS.csv').open('w',newline='') as f:
    fields=['dataset','case','target','windows','valid','selected_match',
            'error_unit','error_median','error_q1','error_q3',
            'contrast_median','contrast_q1','contrast_q3',
            'raw_contrast_median','retained_fraction_median',
            'J_median','J_q1','J_q3']
    writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader()
    for (dataset,name,target),group in sorted(target_groups.items()):
        valid=[r for r in group if r['valid']]
        record={'dataset':dataset,'case':name,'target':target,
                'windows':len(group),'valid':len(valid),
                'selected_match':sum(r['chosen_hypothesis_matches'] for r in group),
                'error_unit':'order' if dataset=='ottawa' else 'Hz'}
        for output,key in [('error','error'),('contrast','contrast_linear'),('J','J')]:
            values=[val(r,key) for r in valid]
            record[output+'_median']=pct(values,50)
            record[output+'_q1']=pct(values,25)
            record[output+'_q3']=pct(values,75)
        record['raw_contrast_median']=pct([val(r,'raw_contrast_linear') for r in valid],50)
        record['retained_fraction_median']=pct([val(r,'retained_pixel_fraction') for r in valid],50)
        writer.writerow(record)
