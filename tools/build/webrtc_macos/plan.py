"""Fail before expensive SDK work if explicit publication reuses an immutable version."""
import json
import os
from urllib.error import HTTPError
from urllib.request import Request,urlopen
from tools.ci.native.process import ROOT
from . import execution,contract


def absent(path):
    token=os.environ.get('GITHUB_TOKEN','');contract.require(token)
    request=Request('https://api.github.com/repos/BOOHTACORD/BOOHTACORD/'+path,headers={
        'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28'})
    try:
        with urlopen(request,timeout=20):pass
    except HTTPError as error:
        if error.code==404:return True
        raise ValueError('SDK version availability is unverified') from None
    return False


def prepare(publish):
    identity=execution.context();inputs=contract.inputs();contract.require(publish in ('true','false'))
    if publish=='true':
        contract.require(os.environ.get('GITHUB_REF')=='refs/heads/master')
        version=inputs['version']
        contract.require(absent('releases/tags/'+version) and absent('git/ref/tags/'+version))
    return dict(status='PASS',scope='candidate-preflight',native_build='NOT_RUN',physical_acceptance='NOT_RUN',
                publish_requested=publish=='true',**identity,version=inputs['version'],recipe_sha256=inputs['recipe_sha256'])


def main():
    path=ROOT/'.out/sdk-plan.json';path.parent.mkdir(parents=True,exist_ok=True);row=dict(status='BLOCKED',native_build='NOT_RUN')
    try:row=prepare(os.environ.get('SDK_PUBLISH_REQUESTED','false'))
    finally:path.write_text(json.dumps(row,sort_keys=True)+'\n')


if __name__=='__main__':main()
