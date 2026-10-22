"""Validate actual app/extension identities inside an exported App Store IPA."""
import hashlib
import plistlib
import zipfile
from pathlib import Path


def verify(path, version, build, application):
    path=Path(path)
    with zipfile.ZipFile(path) as archive:
        apps=[n for n in archive.namelist() if n.startswith('Payload/') and n.count('/')==2 and n.endswith('.app/Info.plist')]
        if len(apps)!=1: raise ValueError('IPA must contain exactly one application')
        parent=apps[0].removesuffix('/Info.plist')
        extensions=[n for n in archive.namelist() if n.startswith(parent+'/PlugIns/') and n.endswith('.appex/Info.plist') and n.count('/')==4]
        if len(extensions)!=1: raise ValueError('IPA must embed exactly the approved screen extension')
        bundles=[]
        for name,expected in [(apps[0],application),(extensions[0],application+'.ScreenShareExtension')]:
            info=plistlib.loads(archive.read(name))
            if (info.get('CFBundleIdentifier'),info.get('CFBundleShortVersionString'),info.get('CFBundleVersion'))!=(expected,version,build):
                raise ValueError('App/extension release identity mismatch')
            bundles.append({'application_id':expected,'version':version,'build':build})
    return {'status':'PASS','bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bundles':bundles}

if __name__ == '__main__':
    import argparse
    import json
    from tools.build.client_identity import load
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa',type=Path)
    parser.add_argument('--application-id',required=True)
    args=parser.parse_args()
    identity=load('ios')
    print(json.dumps(verify(args.ipa,identity['version'],identity['native_build'],args.application_id),indent=2))
