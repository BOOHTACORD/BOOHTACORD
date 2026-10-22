"""Private routing journal. No local account or DM identifier is published."""
import hashlib
import json
import secrets
import sqlite3
import threading
import time
from pathlib import Path
from .policy import publication, require

class Store:
    def __init__(self, root):
        self.root=Path(root);self.root.mkdir(mode=0o700,parents=True,exist_ok=True)
        self.lock=threading.RLock()
        self.db=sqlite3.connect(self.root/'routing.sqlite',check_same_thread=False)
        self.db.row_factory=sqlite3.Row
        self.db.executescript('''PRAGMA journal_mode=WAL;
          CREATE TABLE IF NOT EXISTS jobs(id INTEGER PRIMARY KEY,tenant TEXT NOT NULL,operation TEXT NOT NULL,
           conversation TEXT NOT NULL,payload TEXT NOT NULL,marker TEXT NOT NULL UNIQUE,state TEXT NOT NULL DEFAULT 'pending',
           issue INTEGER,comment INTEGER,created INTEGER NOT NULL,UNIQUE(tenant,operation));
          CREATE TABLE IF NOT EXISTS conversations(tenant TEXT,conversation TEXT,issue INTEGER UNIQUE,PRIMARY KEY(tenant,conversation));
          CREATE TABLE IF NOT EXISTS replies(id INTEGER PRIMARY KEY AUTOINCREMENT,comment INTEGER NOT NULL UNIQUE,tenant TEXT,conversation TEXT,body TEXT NOT NULL);
          CREATE TABLE IF NOT EXISTS nonces(tenant TEXT,nonce TEXT,created INTEGER,PRIMARY KEY(tenant,nonce));
          CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);
        ''')
        self.db.commit()
    def get(self,key,default):
        with self.lock:
            row=self.db.execute('SELECT value FROM settings WHERE key=?',(key,)).fetchone()
            return row[0] if row else default
    def set(self,key,value):
        with self.lock,self.db:self.db.execute('INSERT INTO settings VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',(key,str(value)))
    def notice(self):return int(self.get('notice','1'))
    def visibility(self,private):
        with self.lock:
            old=self.get('private','unknown')
            # Becoming public changes the agreement; old private consent cannot publish.
            if old=='true' and not private:
                self.set('notice',self.notice()+1)
                with self.db:self.db.execute("UPDATE jobs SET state='cancelled' WHERE state='pending'")
            self.set('private','true' if private else 'false')
    def nonce(self,tenant,nonce,now):
        with self.lock,self.db:
            self.db.execute('DELETE FROM nonces WHERE created<?',(now-600,))
            try:self.db.execute('INSERT INTO nonces VALUES(?,?,?)',(tenant,nonce,now))
            except sqlite3.IntegrityError:raise ValueError('Support request replayed') from None
    def blob(self,tenant,operation,index):
        # Paths use server-generated hashes, never client filenames.
        return self.root/(hashlib.sha256(f'{tenant}/{operation}/{index}'.encode()).hexdigest()[:32])
    def submit(self,tenant,value):
        publication(value,self.notice())
        payload=json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False)
        with self.lock,self.db:
            existing=self.db.execute('SELECT id,payload FROM jobs WHERE tenant=? AND operation=?',(tenant,value['operation_id'])).fetchone()
            if existing:
                require(existing['payload']==payload);return existing['id']
            now=int(time.time())
            # Public contact endpoint: finite global and per-installation publication budget.
            require(self.db.execute('SELECT count(*) FROM jobs WHERE created>?',(now-86400,)).fetchone()[0]<200)
            require(self.db.execute('SELECT count(*) FROM jobs WHERE tenant=? AND created>?',(tenant,now-3600)).fetchone()[0]<30)
            for index,item in enumerate(value['files']):
                path=self.blob(tenant,value['operation_id'],index)
                require(path.is_file() and not path.is_symlink() and path.stat().st_size==item['size'])
                with path.open('rb') as source:require(hashlib.file_digest(source,'sha256').hexdigest()==item['sha256'])
            row=self.db.execute('INSERT INTO jobs(tenant,operation,conversation,payload,marker,created) VALUES(?,?,?,?,?,?)',
                (tenant,value['operation_id'],value['conversation'],payload,secrets.token_hex(16),now))
            return row.lastrowid
    def pending(self):
        with self.lock:
            return [dict(r) for r in self.db.execute("SELECT j.*,c.issue AS existing_issue FROM jobs j LEFT JOIN conversations c USING(tenant,conversation) WHERE j.state IN ('pending','uncertain') AND NOT EXISTS(SELECT 1 FROM jobs earlier WHERE earlier.tenant=j.tenant AND earlier.conversation=j.conversation AND earlier.id<j.id AND earlier.state IN ('pending','uncertain')) ORDER BY j.id LIMIT 20")]
    def publishing(self,job):
        with self.lock,self.db:self.db.execute("UPDATE jobs SET state='uncertain' WHERE id=?",(job,))
    def published(self,job,issue,comment=None):
        with self.lock,self.db:
            row=self.db.execute('SELECT tenant,conversation FROM jobs WHERE id=?',(job,)).fetchone()
            self.db.execute('INSERT INTO conversations VALUES(?,?,?) ON CONFLICT(tenant,conversation) DO NOTHING',(row['tenant'],row['conversation'],issue))
            self.db.execute("UPDATE jobs SET state='published',issue=?,comment=? WHERE id=?",(issue,comment,job))
    def reply(self,issue,comment,body):
        with self.lock,self.db:
            route=self.db.execute('SELECT tenant,conversation FROM conversations WHERE issue=?',(issue,)).fetchone()
            if not route or self.db.execute('SELECT 1 FROM jobs WHERE comment=?',(comment,)).fetchone():return False
            return self.db.execute('INSERT OR IGNORE INTO replies(comment,tenant,conversation,body) VALUES(?,?,?,?)',(comment,route['tenant'],route['conversation'],body)).rowcount==1
    def replies(self,tenant,after):
        with self.lock:return [dict(r) for r in self.db.execute('SELECT id,conversation,body FROM replies WHERE tenant=? AND id>? ORDER BY id LIMIT 100',(tenant,after))]
