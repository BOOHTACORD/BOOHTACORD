"""Strict public source/run parameters for the retained compatible rollback rehearsal."""
import json
import os
from pathlib import Path
import re
import subprocess
from .plan import require


def rollback_inputs(env):
    result={}
    for role in ('current','previous'):
        revision=env.get(role.upper()+'_SOURCE','');run=env.get(role.upper()+'_RUN','')
        require(re.fullmatch('[0-9a-f]{40}',revision) and re.fullmatch('[1-9][0-9]{0,19}',run))
        result[role]={'head':revision,'run':int(run),'equivalent_master':revision}
    require(result['current']['head']!=result['previous']['head'])
    return result


def main():
    value=rollback_inputs(os.environ)
    # Validated positional objects only; never shell command interpolation.
    subprocess.run(['git','fetch','--no-tags','origin',value['current']['head'],value['previous']['head']],check=True)
    target=Path('.out/issue60/ci-inputs.json');target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(value)+'\n')


if __name__=='__main__':main()
