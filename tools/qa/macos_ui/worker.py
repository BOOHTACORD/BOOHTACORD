"""Executed only from the isolated runtime prepared by run.py."""
import hashlib
import http.client
from http.cookies import SimpleCookie
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess

from tools.qa.local_features.stack import Stack


def private_json(path, data):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as handle:
        json.dump(data, handle)


def fixture(stack):
    cookie = ''
    def request(path, method='GET', body=None):
        client=http.client.HTTPSConnection('localhost',4850,context=ssl._create_unverified_context(),timeout=15)
        try:
            client.request(method,'/api/v1'+path,None if body is None else json.dumps(body),{'Origin':'https://localhost:4850','Cookie':cookie,'Content-Type':'application/json'})
            response=client.getresponse()
            raw=response.read()
            return response.status,json.loads(raw) if raw else None,dict(response.getheaders())
        finally:
            client.close()
    status,_,headers=request('/auth/login','POST',{'login':'qa_admin','password':stack.password})
    if status != 204:
        raise RuntimeError('Owned administrator fixture authentication failed')
    jar=SimpleCookie(headers['Set-Cookie'])
    cookie='vp_session='+jar['vp_session'].value
    status,category,_=request('/admin/categories','POST',{'name':'QaAudio'})
    if status != 201:
        raise RuntimeError('Owned category fixture failed')
    status,_,_=request('/admin/categories/'+category['id']+'/channels','POST',{'name':'QaVoice','kind':'VOICE'})
    if status != 201:
        raise RuntimeError('Owned voice channel fixture failed')
    status,_,_=request('/admin/categories/'+category['id']+'/channels','POST',{'name':'QaText','kind':'TEXT'})
    if status != 201: raise RuntimeError('Owned text channel fixture failed')
    status,_,_=request('/auth/register','POST',{'login':'qa_audio_a','password':stack.password})
    if status != 201:
        raise RuntimeError('Owned second-account fixture failed')


def require_ports_available(ports):
    for kind, port in ports.items():
        protocol=socket.SOCK_DGRAM if kind=="sfu_udp" else socket.SOCK_STREAM
        with socket.socket(socket.AF_INET,protocol) as probe:
            probe.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
            probe.bind(("127.0.0.1",port))


def main():
    base=Path(__file__).resolve().parent
    configuration=json.loads((base/'configuration.json').read_text())
    work=base/'stack'; work.mkdir()
    stack=Stack(Path(configuration['root']),work)
    try:
        require_ports_available(configuration['ports'])
        subprocess.run(['npm','exec','vite','build','--','--outDir',str(base/'web-dist')],cwd=Path(configuration['root'])/'clients/web',env=dict(os.environ,VITE_PUBLIC_ORIGIN='https://localhost:4850'),check=True)
        stack.start()
        private_json(base/'browser-private.json',{'password':stack.password,'origin':'https://localhost:4850','owner':stack.owner,'work':str(base)})
        with socket.create_connection(('127.0.0.1',4850)) as plain:
            with ssl._create_unverified_context().wrap_socket(plain,server_hostname='localhost') as secure:
                pin=hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()
        fixture(stack)
        modes=('debug','release') if configuration['mode']=='both' else (configuration['mode'],)
        flutter=base/'flutter'
        subprocess.run(['flutter','pub','get','--offline'],cwd=flutter,check=True)
        subprocess.run(['flutter','test','--no-pub','test/desktop_window_options_test.dart','test/profile_screen_test.dart','--reporter','expanded'],cwd=flutter,check=True)
        subprocess.run(['flutter','test','--no-pub','test/workspace_screen_test.dart','--name','workspace resize preserves','--reporter','expanded'],cwd=flutter,check=True)
        for mode in modes:
            defines=base/(mode+'-private-defines.json')
            private_json(defines,{'QA_API_BASE':'https://localhost:4850/api/v1','QA_CERT_SHA256':pin,'QA_PASSWORD':stack.password,'QA_LOGIN':'qa_admin' if mode=='debug' else 'qa_audio_a'})
            subprocess.run(['flutter','build','macos','--'+mode,'--no-pub','-t','integration_test/macos_ui_native_app.dart','--dart-define-from-file',str(defines)],cwd=flutter,check=True)
            artifact=flutter/'build/macos/Build/Products'/mode.capitalize()/'BOOHTACORD.app'
            print(f'{mode} QA artifact: {artifact}',flush=True)
        print('Manual QA ready. Exit voice and close QA app before pressing Enter to remove this owned stack and disposable builds.',flush=True)
        input()
    finally:
        stack.close()
        print('Owned macOS UI stack removed',flush=True)


if __name__ == '__main__':
    main()
