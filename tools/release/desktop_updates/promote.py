"""Promote a signed desktop artifact only after its immutable asset is published."""
import argparse
import json
from pathlib import Path
from urllib.parse import urlsplit, unquote
from tools.release.client_updates.catalog import mutate
from .verify import verify


def promote(catalog, revision, release, envelope, package, public_key, *, arch, openssl='openssl'):
    payload=verify(envelope,package,public_key,openssl)
    if payload['arch'] not in (arch,'any'):raise ValueError('Selector architecture mismatch')
    tag=payload['download_url'].split('/')[-2]
    expected='https://github.com/BOOHTACORD/BOOHTACORD/releases/tag/'+tag
    if (release.get('draft') is not False or release.get('prerelease') is not False
            or not release.get('published_at') or release.get('tag_name')!=tag
            or release.get('html_url')!=expected):raise ValueError('Release is not published at the selected immutable tag')
    matching=[a for a in release.get('assets',[]) if a.get('browser_download_url')==payload['download_url']]
    if (len(matching)!=1 or matching[0].get('state')!='uploaded' or matching[0].get('size')!=payload['size']
            or matching[0].get('digest')!='sha256:'+payload['sha256']):raise ValueError('Published asset digest/size differs or cannot be authenticated')
    target={k:payload[k] for k in ['release_id','release_order','version','native_build','expires_at']}
    target.update(priority='normal',published_at=release['published_at'],summary='BOOHTACORD '+payload['version']+' ('+payload['native_build']+').',release_notes_url=expected,
        requirements={'supported_arches':[arch],'min_os_version':payload['min_os_version']},
        action={'kind':'open_download_page','url':expected},install_artifact=envelope)
    return mutate(Path(catalog),revision,(payload['platform'],payload['distribution'],payload['channel'],arch),'published',target,allow_new_selector=True)


def main():
    parser=argparse.ArgumentParser()
    for field in ['catalog','release','envelope','package','public-key']:parser.add_argument('--'+field,type=Path,required=True)
    parser.add_argument('--expected-revision',type=int,required=True);parser.add_argument('--arch',choices=['arm64','x64'],required=True);parser.add_argument('--openssl',default='openssl')
    a=parser.parse_args()
    result=promote(a.catalog,a.expected_revision,json.loads(a.release.read_text()),json.loads(a.envelope.read_text()),a.package,a.public_key,arch=a.arch,openssl=a.openssl)
    print('Signed desktop catalog candidate revision '+str(result['catalog_revision']))
if __name__=='__main__':main()
