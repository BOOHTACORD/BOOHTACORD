"""No Windows coverage loss or rebuild may hide behind the stable status."""
from .aggregate import ROLES
from .transfer import require

SUFFIX='-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
RELEASE='clients/flutter/build/windows/x64/runner/Release/'


def command(job,text):
    found=[s for s in job['steps'] if s.get('run')==text]
    require(len(found)==1 and found[0].get('if') is None and not found[0].get('continue-on-error'))
    return job['steps'].index(found[0])


def downloads(job):
    return [s for s in job['steps'] if s.get('uses','').startswith('actions/download-artifact@')]


def validate(document):
    try:
        jobs=document['jobs'];require(set(jobs)==ROLES|{'windows'})
        for name in ROLES:
            job=jobs[name]
            require(job['runs-on']=='windows-2022' and not job.get('if') and not job.get('continue-on-error')
                    and not job.get('strategy') and job.get('needs')==('windows-build' if name=='windows-gui-sfu' else None))
        unit,build,gui=(jobs[n] for n in ('windows-native-unit','windows-build','windows-gui-sfu'))
        flutter_index=command(unit,'python -m tools.ci.native.flutter')
        publisher_index=command(unit,'node --test tools/release/android/publish.test.mjs tools/release/android/publish_retries.test.mjs tools/release/android/publish_conflicts.test.mjs tools/release/windows/publish.test.mjs tools/release/native_contract/publish.test.mjs')
        require(publisher_index<flutter_index)
        native=[s for s in unit['steps'] if 'cl.exe /nologo /std:c++17' in s.get('run','') and 'windows.cpp' in s.get('run','')]
        reject=[s for s in unit['steps'] if 'Recovery monitor did not reject' in s.get('run','')]
        require(len(native)==len(reject)==1 and not native[0].get('if') and not reject[0].get('if'))
        build_index=command(build,'python -m tools.build.windows.run --ci-acceptance')
        seal_index=command(build,'python -m tools.ci.windows_gates.transfer seal')
        require(build_index<seal_index)
        all_builds=[s for job in jobs.values() for s in job['steps']
                    if 'tools.build.windows.run' in s.get('run','') or 'flutter build windows' in s.get('run','')]
        require(len(all_builds)==1)
        for prefix,path in [('BOOHTACORD-windows-x64',RELEASE),('BOOHTACORD-windows-installer-x64','.out/releases/windows/'),
                            ('windows-transfer','.out/ci/windows-transfer.json')]:
            uploads=[s for s in build['steps'] if s.get('with',{}).get('name')==prefix+SUFFIX]
            require(len(uploads)==1 and not uploads[0].get('if') and seal_index<build['steps'].index(uploads[0])
                    and uploads[0]['with']['path']==path and uploads[0]['with']['if-no-files-found']=='error')
        expected=[{'name':prefix+SUFFIX,'path':path} for prefix,path in [('BOOHTACORD-windows-x64',RELEASE),
            ('BOOHTACORD-windows-installer-x64','.out/releases/windows/'),('windows-transfer','.out/ci/')]]
        require([s['with'] for s in downloads(gui)]==expected and all(not s.get('if') for s in downloads(gui)))
        require(command(gui,'python -m tools.ci.windows_gates.transfer verify')
                < command(gui,'python -m tools.ci.windows_gates.acceptance'))
        require(not any(s.get('uses')=='./.github/actions/flutter-setup' for s in gui['steps']))
        retained=[s for s in gui['steps'] if s.get('with',{}).get('name')=='windows-acceptance'+SUFFIX]
        require(len(retained)==1 and retained[0].get('if')=='always()'
                and retained[0]['with']['path']=='.out/ci/windows-acceptance.json'
                and retained[0]['with']['if-no-files-found']=='error')
        job=jobs['windows']
        require(job.get('name','windows')=='windows' and job.get('if')=='always()'
                and set(job['needs'])==ROLES and not job.get('continue-on-error'))
        require([s['with'] for s in downloads(job)]==[{'name':'windows-acceptance'+SUFFIX,'path':'.out/ci/'}])
        i=command(job,'python -m tools.ci.windows_gates.aggregate')
        require(job['steps'][i].get('env')=={'WINDOWS_NEEDS':'${{ toJSON(needs) }}'})
    except (KeyError,TypeError,AttributeError,IndexError) as error:
        raise ValueError('Incomplete mandatory Windows gate') from error
