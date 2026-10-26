"""A durable outbox; uncertain writes reconcile and never blindly repost."""
import json
import re
import time
from datetime import datetime,timezone,timedelta
from .policy import REPOSITORY,reply_allowed,require
from .broker import IssueMissing

class Publisher:
    def __init__(self,store,broker):self.store=store;self.broker=broker;self.permissions={}
    def publish(self):
        self.store.visibility(self.broker('repository')['private'])
        self.store.set('github_checked_at',int(time.time()))
        for job in self.store.pending():
            payload=json.loads(job['payload'])
            if job['state']=='uncertain':
                target=job['issue'] or job['existing_issue']
                if target and not self.broker('issue',issue=target)['exists']:
                    self.store.missing(job['id'],target);return
                found=self.broker('find_operation',marker=job['marker'])
                if found:self.store.published(job['id'],found['issue'],found.get('id'))
                continue
            if payload['consent_version']!=self.store.notice():continue
            if job['existing_issue'] and not self.broker('issue',issue=job['existing_issue'])['exists']:
                self.store.missing(job['id'],job['existing_issue']);job['existing_issue']=None
            body=payload['body']
            for index,item in enumerate(payload['files']):
                release=self.broker('asset_release')
                blob=self.store.blob(job['tenant'],job['operation'],index)
                suffix=re.sub('[^a-zA-Z0-9.]','_',item['name'])[-100:]
                asset=self.broker('upload_asset',release=release['id'],blob=blob.name,name=f"{job['marker']}-{index}-{suffix}",size=item['size'],sha256=item['sha256'])
                label=re.sub(r'[\[\]()*_`<>!\\]','_',item['name'])
                body+=f"\n\n[{label}]({asset['url']})"
            body+=f"\n\n<!-- boohtacord-support:{job['marker']} -->"
            # State is durable before the network write. A lost response cannot duplicate a ticket.
            self.store.publishing(job['id'],job['existing_issue'])
            if job['existing_issue']:
                try:result=self.broker('create_comment',issue=job['existing_issue'],body=body)
                except IssueMissing:
                    if not self.broker('issue',issue=job['existing_issue'])['exists']:
                        self.store.missing(job['id'],job['existing_issue']);return
                    raise
            else:
                author=payload.get('user_id') or self.store.author(job['tenant'],job['conversation'])
                title=f'Обращение BOOHTACORD — user_id: {author}' if author else 'Обращение из публичной поддержки BOOHTACORD'
                result=self.broker('create_issue',title=title,body=body)
            self.store.published(job['id'],result['issue'],result.get('id'))
            for index in range(len(payload['files'])):
                self.store.blob(job['tenant'],job['operation'],index).unlink(missing_ok=True)
            # Refresh joins so a second queued message goes to the newly created issue.
            return
    def receive(self):
        since=self.store.get('comments_since',(datetime.now(timezone.utc)-timedelta(days=1)).isoformat())
        started=datetime.now(timezone.utc)-timedelta(minutes=2)
        for page in range(1,101):
            rows=self.broker('comments',since=since,page=page)
            for row in rows:
                with self.store.lock:
                    known=self.store.db.execute('SELECT 1 FROM conversations WHERE issue=?',(row['issue'],)).fetchone()
                    forwarded=self.store.db.execute('SELECT 1 FROM jobs WHERE comment=?',(row['id'],)).fetchone() is not None
                if not known or forwarded or '<!-- boohtacord-support:' in row['body']:continue
                login=row['login'];entry=self.permissions.get(login)
                if not entry or entry[0]<time.time()-60:
                    entry=(time.time(),self.broker('permission',login=login)['permission']);self.permissions[login]=entry
                if reply_allowed(entry[1],forwarded):
                    body=row['body']
                    if len(body)>7800:body=body[:7800]+f'\n\nПолный ответ: https://github.com/{REPOSITORY}/issues/{row["issue"]}#issuecomment-{row["id"]}'
                    if body and '\x00' not in body:self.store.reply(row['issue'],row['id'],body)
            if len(rows)<100:
                self.store.set('comments_since',started.isoformat());return
        # Do not advance the cursor if pagination was exhausted.
