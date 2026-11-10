"""Create a synthetic update catalog only inside the owned native QA fixture."""
import json
from pathlib import Path


def write_catalog(work: Path, release_order: int) -> Path:
    if type(release_order) is not int or not 1 <= release_order < 2147483647:
        raise ValueError('Invalid synthetic release order')
    future = release_order + 1
    target = dict(release_id='qa-required-update', release_order=future,
                  minimum_release_order=future, version='99.0.0', native_build='999',
                  priority='important', published_at='2026-01-01T00:00:00Z',
                  summary='Тестовое обязательное обновление', release_notes_url='/qa-update-help',
                  requirements={'supported_arches':['any']},
                  action={'kind':'open_instructions','url':'/qa-update-help'})
    entries = [dict(platform=platform, distribution='development', channel='development',
                    arch=arch, state='published', target=target)
               for platform in ('android','ios') for arch in ('any','x64','arm64','armv7')]
    path = work / 'synthetic-update-catalog.json'
    path.write_text(json.dumps(dict(schema_version=1,catalog_revision=1,
                                   application_family='boohtacord',entries=entries)),encoding='utf8')
    path.chmod(0o644)
    return path
