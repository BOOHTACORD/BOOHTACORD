"""Feature tests + production-component captures + honest runtime/visual status."""
import argparse
import datetime
import json
import os
import shutil
import subprocess
from pathlib import Path
from .policy import validate_selection, changed_paths
from .report import write_report
from .doctor import devices, boot_android


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--feature', action='append', help='repeat; default all registered features')
    parser.add_argument('--platform', action='append', choices=['web','android','ios'])
    parser.add_argument('--base', default='origin/master', help='coverage base (default origin/master)')
    parser.add_argument('--full-unit', action='store_true', default=True, help='all client unit tests (default)')
    parser.add_argument('--real-stack', action='store_true', default=True, help='owned real API/SFU (default)')
    parser.add_argument('--native-device', action='append', default=[], metavar='PLATFORM:ID')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    catalog = json.loads((Path(__file__).with_name('features.json')).read_text())
    features = sorted(set(args.feature or catalog))
    if set(features)-set(catalog): parser.error('Unknown feature; see features.json')
    platforms = sorted(set(args.platform or ['web','android','ios']))
    if args.base:
        paths = changed_paths(root,args.base)
        validate_selection(paths,catalog,set(features))
    destination = root/'.out/local-features'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    destination.mkdir(parents=True)
    if not args.native_device:
        inventory=devices()
        if 'android' in platforms and 'android' not in inventory:
            print('stage=starting-owned-android-emulator',flush=True)
            device=boot_android(destination/'emulator-start.log')
            if device:inventory['android']=device
        args.native_device=[platform+':'+device for platform,device in inventory.items()]
    import time
    started=time.time()
    stages=[]
    environment=dict(os.environ, VITE_PUBLIC_ORIGIN='https://localhost:4810',
                     FLUTTER_ROOT=os.environ.get('FLUTTER_ROOT','/opt/homebrew/share/flutter'),
                     BOOHTACORD_VISUAL_CAPTURE_DIR=str(destination/'flutter-captures'))
    def stage(name, command, cwd, env=environment):
        print('stage='+name,flush=True)
        with (destination/(name+'.log')).open('w') as log:
            try:
                outcome=subprocess.run(command,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
                status='PASS' if outcome.returncode==0 else 'FAIL'
            except (OSError, subprocess.TimeoutExpired): status='BLOCKED'
        stages.append({'name':name,'status':status})
        print(name+'='+status,flush=True)
    web=root/'clients/web'; flutter=root/'clients/flutter'
    if 'web' in platforms:
        if args.full_unit: stage('web-unit',['npm','test','--','--run'],web)
        stage('web-build',['npm','run','build'],web)
        configs=sorted({c for f in features for c in catalog[f]['web']})
        for config in configs:
            name='web-'+Path(config).parent.name
            stage(name,['node','node_modules/@playwright/test/cli.js','test','-c',config,
                        '--output',str(destination/name)],web)
        if args.real_stack:
            for width in [1440,393]:
                stage('web-real-stack-'+str(width),['python3','-m','tools.qa.client_lifecycle.run',
                      '--critical','--portable-proxy','--width',str(width)],root)
        else: stages.append({'name':'web-real-stack','status':'BLOCKED'})
    if {'android','ios'} & set(platforms):
        tests=sorted({t for f in features for t in catalog[f]['flutter']})
        if args.full_unit: stage('flutter-unit',['flutter','test'],flutter)
        stage('flutter-component-captures',['flutter','test',*tests],flutter)
        for platform in ['android','ios']:
            if platform not in platforms: continue
            ids=[item.split(':',1)[1] for item in args.native_device if item.startswith(platform+':')]
            if not ids:
                stages.append({'name':platform+'-runtime','status':'BLOCKED'})
            else:
                stage(platform+'-runtime',['python3','-m','tools.qa.local_features.native',
                                          '--platform',platform,'--device',ids[0],
                                          '--output',str(destination/(platform+'-runtime'))],root)
    images=[]
    for path in destination.rglob('*.png'):
        if 'images' not in path.relative_to(destination).parts:
            images.append((str(path.relative_to(destination)),path))
    if args.real_stack:
        for path in (root/'.out/client-lifecycle').glob('*/*.png'):
            if path.stat().st_mtime >= started:
                images.append(('web-real-stack/'+path.parent.name+'/'+path.name,path))
    source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    dirty=subprocess.check_output(['git','diff','--binary'],cwd=root)
    import hashlib
    source += ' diff-sha256='+hashlib.sha256(dirty).hexdigest()
    report=write_report(destination,stages,source,features,platforms,images)
    report['scenario_sources']={str(path.relative_to(root)):hashlib.sha256(path.read_bytes()).hexdigest()
        for directory in [root/'tools/qa/local_features',root/'clients/flutter/integration_test',root/'clients/flutter/test_driver']
        for path in directory.rglob('*') if path.is_file() and path.suffix in {'.py','.json','.sh','.dart'}}
    (destination/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('report='+str(destination/'index.html'),flush=True)
    print('status='+report['status'],flush=True)
    return 0 if report['status']=='REVIEW_REQUIRED' else 1

if __name__ == '__main__': raise SystemExit(main())
