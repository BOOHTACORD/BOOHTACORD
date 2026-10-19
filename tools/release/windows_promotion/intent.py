"""Immutable public intent binding exactly one Windows catalog delta to release assets."""
import hashlib
import json
import re
from tools.release.client_updates.catalog import SELECTOR, validate as catalog

PATH='deploy/client-updates/catalog.json'
DIRECTORY='deploy/client-updates/promotions/'
KEY=('windows','direct','stable','x64')
REPOSITORY='Egkurilov/BOOHTACORD'


def require(value):
    if not value:raise ValueError('Windows promotion source, selector, revision or evidence differs')


def raw(value):return (json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False)+'\n').encode()
def digest(value):return hashlib.sha256(value).hexdigest()
def identifier(record):return digest(raw(record))
def branch(record):return 'codex/windows-catalog-'+record['release']['tag']+'-'+identifier(record)[:16]
def entry(document):return next(row for row in document['entries'] if tuple(row[k] for k in SELECTOR)==KEY)


def delta(before,after):
    catalog(before);catalog(after)
    require(after['catalog_revision']==before['catalog_revision']+1)
    left={tuple(row[k] for k in SELECTOR):row for row in before['entries']}
    right={tuple(row[k] for k in SELECTOR):row for row in after['entries']}
    require(left.keys()==right.keys() and KEY in left and all(left[k]==right[k] for k in left if k!=KEY))
    require({k:v for k,v in before.items() if k not in ('entries','catalog_revision')}==
            {k:v for k,v in after.items() if k not in ('entries','catalog_revision')})
    row=right[KEY];target=row.get('target');require(row['state']=='published' and isinstance(target,dict))
    require(set(row)==set(SELECTOR)|{'state','target'})
    require(re.fullmatch(r'\d+\.\d+\.\d+',target['version']) and re.fullmatch('[1-9][0-9]*',target['native_build']))
    old=left[KEY].get('target')
    if old:
        require(target['release_order']>old['release_order'] and int(target['native_build'])>=int(old['native_build'])
                and tuple(map(int,target['version'].split('.')))>=tuple(map(int,old['version'].split('.'))))
        require(not old.get('install_artifact') or bool(target.get('install_artifact')))
    return target


def create(before_raw,after_raw,base,release):
    before,after=json.loads(before_raw),json.loads(after_raw)
    target=delta(before,after)
    record={'schema_version':1,'kind':'windows-catalog-promotion','repository':REPOSITORY,'selector':list(KEY),
      'base_revision':base,'expected_catalog_revision':before['catalog_revision'],'catalog_revision':after['catalog_revision'],
      'base_catalog_sha256':digest(before_raw),'catalog_sha256':digest(after_raw),'target_sha256':digest(raw(target)),
      'release':release}
    validate(record,before_raw,after_raw)
    return record


def validate(record,before_raw,after_raw):
    require(set(record)=={'schema_version','kind','repository','selector','base_revision','expected_catalog_revision',
        'catalog_revision','base_catalog_sha256','catalog_sha256','target_sha256','release'})
    require(record['schema_version']==1 and record['kind']=='windows-catalog-promotion'
            and record['repository']==REPOSITORY and record['selector']==list(KEY)
            and re.fullmatch('[0-9a-f]{40}',record['base_revision']))
    before,after=json.loads(before_raw),json.loads(after_raw);target=delta(before,after)
    require(record['expected_catalog_revision']==before['catalog_revision'] and record['catalog_revision']==after['catalog_revision']
            and record['base_catalog_sha256']==digest(before_raw) and record['catalog_sha256']==digest(after_raw)
            and record['target_sha256']==digest(raw(target)))
    release=record['release']
    require(set(release)=={'tag','source_revision','manifest_sha256','archive_sha256','checksums_sha256','asset_inventory_sha256'}
            and release['tag']=='windows-v'+target['version'] and re.fullmatch('[0-9a-f]{40}',release['source_revision'])
            and all(re.fullmatch('[0-9a-f]{64}',release[k]) for k in ('manifest_sha256','archive_sha256','checksums_sha256','asset_inventory_sha256')))
    url='https://github.com/'+REPOSITORY+'/releases/tag/'+release['tag']
    require(target['action']=={'kind':'open_download_page','url':url})
    if target.get('release_notes_url') is not None:require(target['release_notes_url']==url)
    return record
