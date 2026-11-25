"""Strict public selector and actual-process observation boundaries for #249."""
import re

ORIGIN = 'https://v.bootybay.ru/api/v1'
RELEASES = 'https://github.com/BOOHTACORD/BOOHTACORD/releases/'
SELECTOR = {'platform':'windows','distribution':'direct','channel':'stable','arch':'x64'}


def require_hosted(environment, system):
    if (system != 'win32' or environment.get('GITHUB_ACTIONS') != 'true' or
            environment.get('RUNNER_ENVIRONMENT') != 'github-hosted'):
        raise RuntimeError('Disposable hosted Windows runner required; never a user installation')


def target(policy):
    try:
        value = policy['target']
        version = value['version']
        if (any(policy.get(k) != v for k,v in SELECTOR.items()) or
                policy['application_family'] != 'boohtacord' or policy['state'] != 'published' or
                type(policy['catalog_revision']) is not int or policy['catalog_revision'] < 1 or
                not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version) or
                tuple(map(int,version.split('.'))) <= (1,0,32) or
                not re.fullmatch(r'[1-9][0-9]{0,8}',value['native_build']) or int(value['native_build']) <= 46 or
                type(value['release_order']) is not int or value['release_order'] <= 46 or
                value['release_id'] != 'windows-direct-stable-r'+str(value['release_order']) or
                value.get('priority') not in {'normal','important'} or
                value['release_notes_url'] != RELEASES+'tag/windows-v'+version or
                value['action'] != {'kind':'open_download_page','url':value['release_notes_url']} or
                not isinstance(value['summary'],str) or not 1 <= len(value['summary']) <= 1024):
            raise ValueError('Unsafe or stale public Windows target')
        return value
    except (KeyError,TypeError,AttributeError) as error:
        raise ValueError('Incomplete public Windows target') from error


def validate_observation(row, mode, release):
    version, build = ('1.0.32',46) if mode == 'old' else (release['version'],int(release['native_build']))
    if (mode not in {'old','current'} or row.get('status') != 'PASS' or row.get('mode') != mode or
            row.get('version') != version or row.get('native_build') != build or
            row.get('version_visible') is not True or row.get('pid_scoped') is not True or
            row.get('offer_visible') is not (mode == 'old') or
            row.get('screenshot') != mode+'-offer.png' or
            (mode == 'old' and row.get('details_version_visible') is not True) or
            (mode == 'current' and row.get('incorrect_status_visible') is not False)):
        raise ValueError('Incomplete native Windows update observation')
