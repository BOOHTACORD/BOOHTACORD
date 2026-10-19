"""Cheap metadata/packaging regressions do not claim a native build or device acceptance."""
import json
from pathlib import Path
import subprocess
import sys
from tools.ci.native.process import ROOT


def main():
    report=dict(status='FAIL',scope='metadata-and-packaging-fixtures',native_build='NOT_RUN',physical_acceptance='NOT_RUN')
    path=ROOT/'.out/ci/macos-fast.json';path.parent.mkdir(parents=True,exist_ok=True)
    try:
        report['source_revision']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        subprocess.run([sys.executable,'-m','unittest','tools.ci.macos.test_host','tools.ci.macos.test_workflow','tools.build.webrtc_macos.test_contract',
                        'tools.build.webrtc_macos.test_extract','tools.build.webrtc_macos.test_execution','tools.build.webrtc_macos.test_assets','tools.build.webrtc_macos.test_plan'],cwd=ROOT,check=True)
        subprocess.run(['bash','tools/build/macos/package.test.sh'],cwd=ROOT,check=True)
        report['status']='PASS'
    finally:path.write_text(json.dumps(report,sort_keys=True)+'\n')


if __name__=='__main__':main()
