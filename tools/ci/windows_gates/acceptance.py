"""Recovery and real GUI/SFU run on exactly the downloaded CI build."""
import json
from tools.ci.native.process import ROOT
from tools.qa.desktop_updates.windows_recovery import run as recovery
from tools.qa.screen_setup.windows import main as gui, validate_result
from tools.build.client_identity import load
from .transfer import verify_workspace, RELEASE, read


def main():
    destination=ROOT/'.out/ci/windows-acceptance.json'
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text('{"status":"FAIL"}\n',encoding='utf-8')
    binding=verify_workspace()
    recovery_report=ROOT/'.out/desktop-recovery/windows-smoke.json'
    recovery(ROOT/RELEASE,load('windows')['native_build'],recovery_report)
    if read(recovery_report).get('status') != 'PASS': raise ValueError('Native recovery failed')
    gui()
    value=read(ROOT/'.out/screen-setup-windows/result.json');validate_result(value)
    # Both actual processes must leave the retained payload unchanged.
    verify_workspace()
    if value.get('manifest_sha256') != binding['release']['artifact-manifest.json']['sha256']:
        raise ValueError('GUI tested another native payload')
    destination.write_text(json.dumps({'source_revision':binding['source_revision'],'status':'PASS',
        'execution':binding['execution'],'manifest_sha256':value['manifest_sha256'],
        'recovery':True,'gui_sfu':True},sort_keys=True)+'\n',encoding='utf-8')


if __name__ == '__main__': main()
