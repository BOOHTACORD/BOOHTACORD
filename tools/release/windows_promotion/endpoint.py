"""Read only the fixed public selector; retain bounded hashes and cache observations."""
import argparse
import copy
import json
from pathlib import Path
from urllib.request import Request, build_opener
from tools.release.delivery.artifact_download import NoRedirect
from . import intent

URL='https://v.bootybay.ru/api/v1/client-updates?platform=windows&distribution=direct&channel=stable&arch=x64'


def expected(catalog):
    row=copy.deepcopy(intent.entry(catalog));target=row.get('target')
    if target:
        for key,empty in (('expires_at',''),('install_artifact',None)):
            if target.get(key)==empty:target.pop(key,None)
        requirements=target.get('requirements',{})
        for key,empty in (('min_os_version',''),('min_android_sdk',0)):
            if requirements.get(key)==empty:requirements.pop(key,None)
    return {'application_family':catalog['application_family'],'catalog_revision':catalog['catalog_revision'],**row}


def observe(catalog,request=None):
    request=request or (lambda value:build_opener(NoRedirect()).open(value,timeout=10))
    with request(Request(URL,headers={'Accept':'application/json','Cache-Control':'no-cache'})) as response:
        intent.require(response.status==200)
        headers=response.headers
        directives={part.strip().lower() for part in headers.get('Cache-Control','').split(',')}
        age=headers.get('Age')
        intent.require('no-store' in directives and 'public' not in directives
            and not any(value.startswith(('max-age=','s-maxage=')) and value.split('=',1)[1]!='0' for value in directives)
            and headers.get('X-Content-Type-Options','').lower()=='nosniff'
            and headers.get('Content-Type','').split(';')[0].strip().lower()=='application/json'
            and (age is None or (age.isdigit() and int(age)==0)))
        raw=response.read(16385);intent.require(len(raw)<=16384)
    policy=json.loads(raw);intent.require(policy==expected(catalog))
    return {'status':'PASS','url':URL,'catalog_revision':policy['catalog_revision'],
        'source_catalog_sha256':intent.digest(intent.raw(catalog)),'policy_sha256':intent.digest(intent.raw(policy)),
        'cache_control_no_store':True,'nosniff':True,'content_type_json':True,'age_seconds':int(age) if age else None}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--catalog',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();args.output.parent.mkdir(parents=True,exist_ok=True)
    record={'schema_version':1,'scope':'public-catalog-only','status':'FAIL','chain':'NOT_RUN','physical_acceptance':'NOT_RUN'}
    try:record['endpoint']=observe(json.loads(args.catalog.read_text()));record['status']='PASS'
    finally:args.output.write_text(json.dumps(record,sort_keys=True)+'\n',encoding='utf-8')


if __name__=='__main__':main()
