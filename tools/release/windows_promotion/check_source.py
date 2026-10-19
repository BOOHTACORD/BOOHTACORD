"""Reject stale or rewritten promotion intents in actual PR/merge-queue CI."""
import json
import os
import re
import subprocess
from tools.ci.native.process import ROOT
from . import intent


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,timeout=30)


def validate(base,head):
    intent.require(re.fullmatch('[0-9a-f]{40}',base) and re.fullmatch('[0-9a-f]{40}',head))
    rows=git('diff','--name-status',base,head).decode().splitlines()
    changes=[row.split('\t') for row in rows if intent.DIRECTORY in row]
    if not changes:return
    intent.require(len(changes)==1 and changes[0][0]=='A')
    path=changes[0][1]
    intent.require({row.split('\t')[-1] for row in rows}=={intent.PATH,path})
    record=json.loads(git('show',head+':'+path));intent.require(path==intent.DIRECTORY+intent.identifier(record)+'.json')
    intent.validate(record,git('show',base+':'+intent.PATH),git('show',head+':'+intent.PATH))


def main():
    event=os.environ.get('GITHUB_EVENT_NAME')
    if event not in ('pull_request','merge_group'):return
    payload=json.loads(open(os.environ['GITHUB_EVENT_PATH'],encoding='utf-8').read())
    base=payload['pull_request']['base']['sha'] if event=='pull_request' else payload['merge_group']['base_sha']
    # Checkout HEAD is GitHub's actual test merge, including a newer master.
    head=git('rev-parse','HEAD').decode().strip()
    validate(base,head)


if __name__=='__main__':main()
