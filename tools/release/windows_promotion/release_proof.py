"""Recheck immutable release/tag metadata without downloading native bytes again."""
import re
from . import intent


def fingerprint(release):
    rows=release.get('assets');intent.require(isinstance(rows,list) and 0<len(rows)<=12)
    assets={}
    for row in rows:
        name=row.get('name');intent.require(isinstance(name,str) and re.fullmatch('[A-Za-z0-9_.-]{1,255}',name) and name not in assets
            and type(row.get('id')) is int and row['id']>0 and row.get('state')=='uploaded'
            and type(row.get('size')) is int and 0<row['size']<=95_000_000
            and re.fullmatch('sha256:[0-9a-f]{64}',row.get('digest','')))
        url=f'https://github.com/{intent.REPOSITORY}/releases/download/{release["tag_name"]}/{name}'
        intent.require(row.get('browser_download_url')==url)
        assets[name]={'id':row['id'],'bytes':row['size'],'digest':row['digest'],'url':url}
    return intent.digest(intent.raw(assets))


def tag_source(api,tag):
    intent.require(re.fullmatch(r'windows-v\d+\.\d+\.\d+',tag))
    value=api.read('/git/ref/tags/'+tag)['object']
    for _ in range(5):
        intent.require(re.fullmatch('[0-9a-f]{40}',value.get('sha','')))
        if value.get('type')=='commit':return value['sha']
        intent.require(value.get('type')=='tag');value=api.read('/git/tags/'+value['sha'])['object']
    raise ValueError('Windows release tag nesting exceeds limit')


def verify(record,api):
    proof=record['release'];release=api.read('/releases/tags/'+proof['tag'])
    intent.require(release.get('tag_name')==proof['tag'] and release.get('draft') is False and release.get('prerelease') is False
        and fingerprint(release)==proof['asset_inventory_sha256'] and tag_source(api,proof['tag'])==proof['source_revision'])
    lookup={row['name']:row for row in release['assets']}
    for name,key in ((f'BOOHTACORD-{proof["tag"]}-x64.zip','archive_sha256'),('artifact-manifest.json','manifest_sha256'),('SHA256SUMS','checksums_sha256')):
        intent.require(lookup[name]['digest']=='sha256:'+proof[key])
