"""Project authenticated exact-head CI results onto canonical server-builder receipts."""
import json
import re


def write_receipts(work,role,revision,observed):
    if (role not in ('current','previous') or not re.fullmatch('[0-9a-f]{40}',revision)
            or observed.get('head')!=revision or observed.get('status')!='success'
            or type(observed.get('run')) is not int or observed['run']<=0
            or set(observed.get('checks',{}))!={'backend','web','contracts'}
            or any(row.get('conclusion')!='success' or type(row.get('id')) is not int or row['id']<=0
                   for row in observed['checks'].values())):
        raise ValueError('Actual exact-revision CI proof is required')
    receipts=work/('checks-'+role);receipts.mkdir()
    for gate in ('backend','web','contracts'):
        (receipts/(gate+'.json')).write_text(json.dumps(dict(source_revision=revision,gate=gate,status='PASS'))+'\n')
    (work/('observed-ci-'+role+'.json')).write_text(json.dumps(observed,sort_keys=True)+'\n')
    return receipts
