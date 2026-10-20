"""All platforms use one contract/publisher; signing stays in protected native jobs."""
from tools.ci.runner_pool.routing import LINUX
from .source import PLATFORMS, require

PUBLISH_IF="github.event_name != 'workflow_dispatch' || !inputs.dry_run"


def command(job,text):
    matches=[s for s in job['steps'] if s.get('run')==text]
    require(len(matches)==1 and not matches[0].get('if') and not matches[0].get('continue-on-error'))
    return job['steps'].index(matches[0])


def validate(workflows):
    try:
        require('native-candidate-builds.yaml' not in workflows)
        for platform in PLATFORMS:
            doc=workflows[platform+'-release.yaml'];job=doc['jobs'][platform+'-release'];steps=job['steps']
            require(doc['on']['workflow_dispatch']['inputs']['dry_run']['type']=='boolean'
                    and doc['on']['workflow_dispatch']['inputs']['dry_run']['default']=='false')
            require(job['runs-on']=={'android':LINUX,'windows':'windows-2022','macos':'macos-26'}[platform]
                    and job['environment']=='production' and job['permissions']=={'contents':'write'})
            checkouts=[s for s in steps if s.get('uses','').startswith('actions/checkout@')]
            require(len(checkouts)==1 and checkouts[0]['with']=={'persist-credentials':'false','fetch-depth':'0'})
            require(job.get('env') == {'NATIVE_RELEASE_DRY_RUN':"${{ github.event_name == 'workflow_dispatch' && inputs.dry_run && 'true' || 'false' }}"})
            pre=command(job,'python -m tools.release.native_contract.run preflight '+platform)
            require(steps[pre].get('id')=='native-source')
            build=command(job,('python3' if platform!='windows' else 'python')+' -m tools.build.'+platform+'.run')
            verified=command(job,'python -m tools.release.native_contract.run assets '+platform)
            require(pre<build<verified)
            sdks=[i for i,s in enumerate(steps) if s.get('uses')=='./.github/actions/flutter-setup']
            require(len(sdks)==1 and pre<sdks[0]<build)
            publishers=[s for s in steps if 'native_contract/publish.mjs' in s.get('run','')]
            require(len(publishers)==1 and publishers[0]['run']=='node tools/release/native_contract/publish.mjs --platform '+platform
                    and publishers[0].get('if')==PUBLISH_IF and not publishers[0].get('continue-on-error')
                    and publishers[0]['env']=={'GITHUB_TOKEN':'${{ secrets.GITHUB_TOKEN }}'} and verified<steps.index(publishers[0]))
            require(not any('action-gh-release@' in s.get('uses','') or 'tools/release/android/publish.mjs' in s.get('run','')
                            or 'tools/release/windows/publish.mjs' in s.get('run','') for s in steps))
            artifacts=[s for s in steps if s.get('with',{}).get('path')=='.out/native-release/'+platform+'/']
            require(len(artifacts)==1 and artifacts[0].get('if')=='always()' and artifacts[0]['with']=={
                'name':'native-release-'+platform+'-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}',
                'path':'.out/native-release/'+platform+'/','if-no-files-found':'error','retention-days':'30'})
            retained=[s for s in steps if s.get('with',{}).get('path')=='clients/flutter/build/release-assets/']
            require(len(retained)==1 and verified<steps.index(retained[0])<steps.index(publishers[0])
                    and retained[0]['with']['if-no-files-found']=='error' and retained[0]['with']['retention-days']=='30')
            require(any('tools/release/native_contract/publish.test.mjs' in s.get('run','') for s in steps))
        unit=workflows['flutter-windows.yaml']['jobs']['windows-native-unit']
        command(unit,'python -m unittest tools.build.desktop_updater.test_macos_recovery')
        paths=[s for s in unit['steps'] if 'windows_paths_test.cpp' in s.get('run','')]
        require(len(paths)==1 and not paths[0].get('if') and not paths[0].get('continue-on-error'))
        require(any(s.get('run')=='node --test tools/release/native_contract/publish.test.mjs'
                    for s in workflows['ci-contracts.yaml']['jobs']['contracts']['steps']))
    except (KeyError,TypeError,AttributeError,IndexError) as error:
        raise ValueError('Incomplete native source/publication contract') from error
