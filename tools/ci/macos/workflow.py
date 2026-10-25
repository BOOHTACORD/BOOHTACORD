"""Cheap PR contracts stay separate from explicit hosted native app/SDK builds and publication."""
from tools.verify.action_pins.trust import MASTER,GUARDS
from .host import require


def commands(job):return [s.get('run','') for s in job.get('steps',[])]


def validate(workflows):
    app=workflows['flutter-macos.yaml'];require(set(app['on'])=={'workflow_dispatch'})
    require(app['on']['workflow_dispatch']['inputs']['full_build']['default']=='false')
    native=app['jobs']['macos'];require(native.get('runs-on')=='macos-26' and not native.get('environment')
        and native.get('if')==MASTER+' && inputs.full_build' and native.get('needs')=='checks')
    require('python -m tools.ci.macos.fast' in commands(app['jobs']['checks']))
    sdk=workflows['webrtc-macos-sdk.yaml'];require(set(sdk['on'])=={'workflow_dispatch'}
        and sdk['on']['workflow_dispatch']['inputs']['publish_sdk']['default']=='false'
        and sdk['concurrency']['cancel-in-progress']=='false')
    build=sdk['jobs']['build'];require(build.get('needs')=='plan' and build.get('timeout-minutes')=='180'
        and build['strategy']['matrix']['include']==[{'arch':'arm64','runner':'macos-26'},{'arch':'x64','runner':'macos-26-intel'}])
    cleanup=[i for i,s in enumerate(build['steps']) if s.get('run')=='python -m tools.build.webrtc_macos.execution --arch "$SDK_ARCH"']
    require(len(cleanup)==1 and build['steps'][cleanup[0]].get('if')=='always()')
    for arch in ('arm64','x64'):
        downloads=[s for s in sdk['jobs']['assemble']['steps'] if s.get('with',{}).get('path')=='.out/sdk-inputs/'+arch]
        require(len(downloads)==1 and downloads[0]['with']['name']=='sdk-'+arch+'-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}')
    require(sdk['jobs']['assemble'].get('needs')=='build')
    publish=sdk['jobs']['publish'];require(publish.get('if')==GUARDS[('webrtc-macos-sdk.yaml','publish')]
        and publish.get('environment')=='production' and publish.get('needs')=='assemble'
        and publish.get('permissions')=={'contents':'write'} and 'python -m tools.build.webrtc_macos.assets' in commands(publish))
    require('python -m tools.ci.macos.host --arch arm64' in commands(workflows['macos-release.yaml']['jobs']['macos-release']))
    for job in (native, workflows['macos-release.yaml']['jobs']['macos-release']):
        steps = job['steps']
        tests = [s for s in steps if s.get('run') == 'python3 -m tools.verify.macos_unit.run']
        require(len(tests) == 1 and not tests[0].get('if') and not tests[0].get('continue-on-error'))
        require(steps.index(tests[0]) < next(i for i,s in enumerate(steps) if s.get('run') == 'python3 -m tools.build.macos.run'))
        uploads = [s for s in steps if s.get('with', {}).get('path') == '.out/checks/macos-unit/']
        require(len(uploads) == 1 and uploads[0].get('if') == 'always()'
                and uploads[0]['with'].get('if-no-files-found') == 'error')
    for job in sdk['jobs'].values():
        for step in job.get('steps',[]):
            require(not step.get('continue-on-error'))
            if step.get('uses','').startswith('actions/upload-artifact@'):
                data=step['with'];require(data.get('if-no-files-found')=='error' and data.get('retention-days')=='30'
                    and all('${{ github.'+key+' }}' in data['name'] for key in ('sha','run_id','run_attempt')))
