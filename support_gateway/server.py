"""Bounded signed HTTP ingress. Request paths and support bodies are never logged."""
import argparse
import functools
import grp
import hashlib
import json
import os
import re
import threading
import time
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit,parse_qs
from .auth import authenticate
from .broker import call,serve
from .policy import MAX_FILE_BYTES,REPOSITORY,require
from .publisher import Publisher
from .store import Store

def run(root,socket_path,address):
    store=Store(root);publisher=Publisher(store,functools.partial(call,socket_path))
    def worker():
        while True:
            try:publisher.publish();publisher.receive()
            except Exception:pass  # Never log provider errors, message bodies or routing IDs.
            # Unsubmitted blobs expire; published files have already been removed.
            for path in store.root.iterdir():
                try:
                    if re.fullmatch('[a-f0-9]{32}(?:\.new)?',path.name) and path.stat().st_mtime<time.time()-86400:path.unlink(missing_ok=True)
                except FileNotFoundError:pass
            time.sleep(10)
    threading.Thread(target=worker,daemon=True).start()
    slots=threading.BoundedSemaphore(8)
    class Handler(BaseHTTPRequestHandler):
        protocol_version='HTTP/1.0'
        def log_message(self,*args):pass
        def do_GET(self):self.handle_request()
        def do_POST(self):self.handle_request()
        def do_PUT(self):self.handle_request()
        def handle_request(self):
            if not slots.acquire(blocking=False):self.respond(503,{'error':'support_busy'});return
            try:
                self.connection.settimeout(20)
                path=urlsplit(self.path);length=int(self.headers.get('Content-Length','0'))
                limit=MAX_FILE_BYTES if self.command=='PUT' else 100_000
                require(0<=length<=limit and 'Transfer-Encoding' not in self.headers)
                if self.command=='GET' and path.path=='/support/v1/status':
                    self.respond(200,dict(repository=REPOSITORY,notice_version=store.notice(),public=store.get('private','false')!='true',ready=int(store.get('github_checked_at','0'))>time.time()-120));return
                body=self.rfile.read(length);require(len(body)==length)
                tenant=authenticate(store,self.headers,self.command,self.path,body,int(time.time()))
                if self.command=='GET' and path.path=='/support/v1/replies':
                    query=parse_qs(path.query);require(set(query)<= {'after'})
                    after=int(query.get('after',['0'])[0]);require(0<=after<2**53)
                    self.respond(200,{'replies':store.replies(tenant,after)});return
                if self.command=='POST' and self.path=='/support/v1/messages':
                    require(int(store.get('github_checked_at','0'))>time.time()-120)
                    job=store.submit(tenant,json.loads(body));self.respond(202,{'accepted':True,'receipt':job});return
                match=re.fullmatch('/support/v1/blobs/([a-f0-9]{32})/([0-9])',self.path)
                if self.command=='PUT' and match:
                    require(0<=length<=MAX_FILE_BYTES)
                    expected=self.headers.get('X-Support-Content-SHA256','');require(hashlib.sha256(body).hexdigest()==expected)
                    target=store.blob(tenant,match[1],int(match[2]))
                    with store.lock:
                        # Bound anonymous staging independently of publication budget.
                        used=sum(p.stat().st_size for p in store.root.iterdir() if re.fullmatch('[a-f0-9]{32}',p.name))
                        require(used+length<=512_000_000)
                        temporary=target.with_suffix('.new')
                        fd=os.open(temporary,os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o600)
                        with os.fdopen(fd,'wb') as out:out.write(body);out.flush();os.fsync(out.fileno())
                        os.replace(temporary,target)
                    self.respond(200,{'stored':True});return
                self.respond(404,{'error':'support_route_not_found'})
            except (ValueError,KeyError,TypeError):self.respond(400,{'error':'support_request_rejected'})
            except Exception:self.respond(503,{'error':'support_unavailable'})
            finally:slots.release()
        def respond(self,status,value):
            body=json.dumps(value).encode();self.send_response(status)
            self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)))
            self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(body)
    host,port=address.rsplit(':',1)
    with ThreadingHTTPServer((host,int(port)),Handler) as server:server.serve_forever()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['api','broker'])
    parser.add_argument('--root',default='/var/lib/boohtacord-support');parser.add_argument('--socket',default='/run/boohtacord-support/github.sock')
    parser.add_argument('--address',default='127.0.0.1:9410');args=parser.parse_args()
    os.umask(0o077)
    if args.mode=='broker':serve(args.socket,args.root,grp.getgrnam('boohtacord-support').gr_gid)
    else:run(Path(args.root),args.socket,args.address)

if __name__=='__main__':main()
