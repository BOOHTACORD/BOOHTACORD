"""Explicit visual review and versioned local screenshot baselines."""
import argparse
import datetime
import html
import hashlib
import json
import shutil
from pathlib import Path


def approve(run, destination, note):
    report=json.loads((run/'report.json').read_text())
    if report['status'] != 'REVIEW_REQUIRED' or not report['screenshots'] or not note.strip():
        raise ValueError('Approve only a passing run with reviewed screenshots and a review note')
    if destination.exists(): raise ValueError('Use a new baseline directory; existing baselines are immutable')
    for image in report['screenshots']:
        source=run/image['path']
        if hashlib.sha256(source.read_bytes()).hexdigest()!=image['sha256']:
            raise ValueError('Screenshot changed after the report; rerun before approving')
    destination.mkdir(parents=True)
    for image in report['screenshots']:
        source=run/image['path']; target=destination/image['path']
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
    report['visual_review']={'status':'REVIEWED','note':note,'date':datetime.datetime.now().isoformat()}
    (destination/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')


def comparison(before, after):
    return {name: 'NEW' if name not in before else 'MISSING' if name not in after
            else 'SAME' if before[name]['sha256']==after[name]['sha256'] else 'CHANGED'
            for name in sorted(set(before)|set(after))}


def compare(before, after, output):
    old=json.loads((before/'report.json').read_text()); new=json.loads((after/'report.json').read_text())
    review=old.get('visual_review')
    if not isinstance(review,dict) or review.get('status')!='REVIEWED':
        raise ValueError('Reference screenshots need explicit visual review')
    for folder,report in [(before,old),(after,new)]:
        for shot in report['screenshots']:
            if hashlib.sha256((folder/shot['path']).read_bytes()).hexdigest()!=shot['sha256']:
                raise ValueError('Screenshot changed after its report; rerun or review again')
    a={s['name']:s for s in old['screenshots']}; b={s['name']:s for s in new['screenshots']}
    changes=comparison(a,b); output.mkdir(parents=True,exist_ok=True)
    rows=[]
    for name,status in changes.items():
        images=[]
        for label,folder,entries in [('before',before,a),('after',after,b)]:
            if name not in entries: images.append('<p>Missing</p>'); continue
            target=output/label/entries[name]['path'];target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(folder/entries[name]['path'],target)
            images.append('<img src="'+str(target.relative_to(output))+'">')
        rows.append('<h2>'+html.escape(name)+' — '+status+'</h2><div class="pair">'+''.join(images)+'</div>')
    (output/'comparison.json').write_text(json.dumps(changes,indent=2)+'\n')
    (output/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Visual comparison</title><style>body{background:#10131c;color:#eee;font:14px system-ui;margin:24px}.pair{display:flex;gap:16px}.pair img{width:48%;object-fit:contain;align-self:start}h2{font-size:16px}</style><h1>Before / After — review every change</h1>'+''.join(rows))


def main():
    parser=argparse.ArgumentParser();sub=parser.add_subparsers(dest='command',required=True)
    a=sub.add_parser('approve');a.add_argument('--run',required=True);a.add_argument('--destination',required=True);a.add_argument('--note',required=True)
    c=sub.add_parser('compare');c.add_argument('--before',required=True);c.add_argument('--after',required=True);c.add_argument('--output',required=True)
    args=parser.parse_args()
    if args.command=='approve':approve(Path(args.run),Path(args.destination),args.note)
    else:compare(Path(args.before),Path(args.after),Path(args.output))

if __name__=='__main__':main()
