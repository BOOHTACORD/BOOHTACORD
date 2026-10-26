"""Install the narrowly scoped support gateway on its existing TLS ingress host."""
import argparse
import os
import subprocess
from pathlib import Path

def command(*args):subprocess.run(args,check=True,stdout=subprocess.DEVNULL)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--release',required=True);args=parser.parse_args()
    release=Path(args.release).resolve()
    if os.geteuid()!=0 or release.parent!=Path('/opt/boohtacord-support') or not (release/'support_gateway/server.py').is_file():
        raise SystemExit('Use a root-owned release under /opt/boohtacord-support')
    if subprocess.run(['id','-u','boohtacord-support'],capture_output=True).returncode:
        command('useradd','--system','--home-dir','/var/lib/boohtacord-support','--shell','/usr/sbin/nologin','--user-group','boohtacord-support')
    command('install','-d','-m','0700','-o','boohtacord-support','-g','boohtacord-support','/var/lib/boohtacord-support')
    common=f'''[Unit]
Description=BOOHTACORD public product support
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory={release}
Environment=PYTHONDONTWRITEBYTECODE=1
ExecStart=/usr/bin/python3 -m support_gateway.server MODE
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictSUIDSGID=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
MemoryMax=256M
TasksMax=32

[Install]
WantedBy=multi-user.target
'''
    broker=common.replace('MODE','broker').replace('[Service]','[Service]\nUser=root\nGroup=boohtacord-support\nRuntimeDirectory=boohtacord-support\nRuntimeDirectoryMode=0750\nReadWritePaths=/run/boohtacord-support')
    api=common.replace('MODE','api').replace('After=network-online.target','After=network-online.target boohtacord-support-broker.service\nRequires=boohtacord-support-broker.service').replace('[Service]','[Service]\nUser=boohtacord-support\nGroup=boohtacord-support\nReadWritePaths=/var/lib/boohtacord-support')
    Path('/etc/systemd/system/boohtacord-support-broker.service').write_text(broker)
    Path('/etc/systemd/system/boohtacord-support.service').write_text(api)
    Path('/etc/nginx/conf.d/00-boohtacord-support-limit.conf').write_text('limit_req_zone $binary_remote_addr zone=boohtacord_support:1m rate=120r/m;\n')
    Path('/etc/nginx/snippets/boohtacord-support.conf').write_text('''location ^~ /support/v1/ {
    auth_basic off;
    access_log off;
    client_max_body_size 25m;
    limit_req zone=boohtacord_support burst=20 nodelay;
    limit_req_status 429;
    proxy_pass http://127.0.0.1:9410;
    proxy_connect_timeout 5s;
    proxy_read_timeout 30s;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
}
''')
    nginx=Path('/etc/nginx/conf.d/boohtacord-otel.conf');original=nginx.read_text()
    include='include /etc/nginx/snippets/boohtacord-support.conf;'
    anchor='location / { return 404; }'
    if include not in original:
        if original.count(anchor)!=1:raise SystemExit('Existing ingress shape changed; no TLS config modified')
        nginx.write_text(original.replace(anchor,include+'\n    '+anchor))
    try:command('nginx','-t')
    except subprocess.CalledProcessError:
        nginx.write_text(original);raise
    command('systemctl','daemon-reload')
    command('systemctl','enable','boohtacord-support-broker.service','boohtacord-support.service')
    command('systemctl','restart','boohtacord-support-broker.service')
    command('systemctl','restart','boohtacord-support.service')
    command('systemctl','reload','nginx')
    print('Support gateway services installed; existing OTLP authentication preserved.')

if __name__=='__main__':main()
