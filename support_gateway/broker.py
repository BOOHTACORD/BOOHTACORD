"""Root-only, fixed-capability Unix broker. GitHub credentials never leave gh."""
import hashlib
import json
import os
import socket
import socketserver
import subprocess
from pathlib import Path
from urllib.parse import urlencode
from .policy import REPOSITORY,ASSET_TAG,broker_request,require

def api(path,method='GET',data=None,*,fd=None):
    command=['gh','api',path,'--method',method,'-H','X-GitHub-Api-Version: 2026-03-10']
    if fd is not None:command+=['-H','Content-Type: application/octet-stream','--input',f'/proc/self/fd/{fd}']
    elif data is not None:command+=['--input','-']
    result=subprocess.run(command,input=json.dumps(data).encode() if data is not None else None,capture_output=True,timeout=90,pass_fds=(fd,) if fd is not None else ())
    if result.returncode:raise RuntimeError('GitHub operation failed')
    return json.loads(result.stdout)

def execute(request,root):
    r=broker_request(request);op=r['operation'];repo=f'repos/{REPOSITORY}'
    if op=='repository':return {'private':bool(api(repo)['private'])}
    if op=='create_issue':
        row=api(repo+'/issues','POST',dict(title=r['title'],body=r['body']));return {'issue':row['number']}
    if op=='create_comment':
        row=api(f"{repo}/issues/{r['issue']}/comments",'POST',dict(body=r['body']));return {'issue':r['issue'],'id':row['id']}
    if op=='permission':return {'permission':api(f"{repo}/collaborators/{r['login']}/permission")['permission']}
    if op=='comments':
        rows=api(repo+'/issues/comments?'+urlencode(dict(since=r['since'],sort='created',direction='asc',per_page=100,page=r['page'])))
        return [dict(id=x['id'],issue=int(x['issue_url'].rsplit('/',1)[1]),body=x.get('body') or '',login=x['user']['login']) for x in rows]
    if op=='issue_comments':return api(f"{repo}/issues/{r['issue']}/comments?per_page=100&page={r['page']}")
    if op=='find_operation':
        marker=f"<!-- boohtacord-support:{r['marker']} -->"
        # Search can lag: a missing result leaves the journal uncertain; no blind retry.
        result=api('search/issues?'+urlencode({'q':f'repo:{REPOSITORY} in:body,comments "boohtacord-support:{r["marker"]}"','per_page':100}))
        for issue in result.get('items',[]):
            if marker in (issue.get('body') or ''):return {'issue':issue['number']}
            for page in range(1,101):
                rows=api(f"{repo}/issues/{issue['number']}/comments?per_page=100&page={page}")
                for row in rows:
                    if marker in (row.get('body') or ''):return {'issue':issue['number'],'id':row['id']}
                if len(rows)<100:break
        return None
    if op=='asset_release':
        rows=api(repo+'/releases?per_page=100')
        for row in rows:
            if row['tag_name']==ASSET_TAG:return {'id':row['id']}
        row=api(repo+'/releases','POST',dict(tag_name=ASSET_TAG,name='Public support attachments',body='Files intentionally published from the public support chat. Do not upload secrets.',draft=False,prerelease=True,make_latest='false'))
        return {'id':row['id']}
    if op=='upload_asset':
        require(api(f"{repo}/releases/{r['release']}")['tag_name']==ASSET_TAG)
        # A held descriptor prevents symlink/path-swap access to root credentials.
        fd=os.open(Path(root)/r['blob'],os.O_RDONLY|os.O_NOFOLLOW)
        try:
            require(os.fstat(fd).st_size==r['size'])
            with os.fdopen(os.dup(fd),'rb') as source:require(hashlib.file_digest(source,'sha256').hexdigest()==r['sha256'])
            os.lseek(fd,0,os.SEEK_SET)
            for page in range(1,101):
                assets=api(f"{repo}/releases/{r['release']}/assets?per_page=100&page={page}")
                for asset in assets:
                    if asset['name']==r['name']:
                        require(asset['size']==r['size'] and asset.get('digest')=='sha256:'+r['sha256'])
                        return {'url':asset['browser_download_url']}
                if len(assets)<100:break
            row=api(f"https://uploads.github.com/{repo}/releases/{r['release']}/assets?"+urlencode({'name':r['name']}),'POST',fd=fd)
            return {'url':row['browser_download_url']}
        finally:os.close(fd)
    raise ValueError('Unsupported operation')

def call(socket_path,operation,**data):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(100);connection.connect(str(socket_path))
        connection.sendall(json.dumps(dict(operation=operation,**data)).encode()+b'\n')
        response=connection.makefile('rb').readline(2_000_001);require(len(response)<=2_000_000)
        value=json.loads(response);require(value['ok']);return value['value']

def serve(socket_path,root,group):
    class Handler(socketserver.StreamRequestHandler):
        def handle(self):
            self.connection.settimeout(10)
            try:
                raw=self.rfile.readline(100_001);require(len(raw)<=100_000)
                value=execute(json.loads(raw),root);reply={'ok':True,'value':value}
            except Exception:reply={'ok':False}
            self.wfile.write(json.dumps(reply).encode()+b'\n')
    path=Path(socket_path);path.unlink(missing_ok=True)
    with socketserver.UnixStreamServer(str(path),Handler) as server:
        os.chown(path,0,group);os.chmod(path,0o660);server.serve_forever()
