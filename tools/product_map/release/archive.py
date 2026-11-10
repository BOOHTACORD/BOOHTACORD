"""Inspect bounded native evidence bytes without extracting archive paths."""
import hashlib
import io
import stat
import zipfile
import zlib

from .publication import match_publication, parse_record

FILES = {'source.json', 'contract.json', 'publication.json', 'feature-snapshot.json'}


def read_native_evidence(raw, candidate):
    if (not isinstance(raw, bytes) or len(raw) > 32_000_000 or
            candidate.get('status') != 'CANDIDATE_UNVERIFIED' or
            len(raw) != candidate.get('artifact_size') or
            'sha256:' + hashlib.sha256(raw).hexdigest() != candidate.get('artifact_digest')):
        raise ValueError('artifact archive digest or size differs')
    try:
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            entries = archive.infolist()
            names = [entry.filename for entry in entries]
            if len(names) != len(FILES) or set(names) != FILES:
                raise ValueError('native evidence archive contents differ')
            for entry in entries:
                if (entry.is_dir() or stat.S_ISLNK(entry.external_attr >> 16) or
                        entry.flag_bits & 1 or entry.file_size > 4_000_000 or
                        entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)):
                    raise ValueError('unsafe native evidence archive entry')
            docs = {entry.filename: parse_record(archive.read(entry)) for entry in entries}
    except (zipfile.BadZipFile, EOFError, OSError, RuntimeError, zlib.error) as error:
        raise ValueError('invalid native evidence archive') from error
    source, contract = docs['source.json'], docs['contract.json']
    fields = ('source_revision', 'platform', 'tag', 'identity', 'execution',
              'repository', 'release_mode', 'tag_verified')
    try:
        if any(source[key] != contract[key] for key in fields):
            raise ValueError('native source and contract differ')
        result = match_publication(docs['feature-snapshot.json'], contract,
                                   docs['publication.json'])
        execution = contract['execution']
        if (result['source_revision'] != candidate['source_revision'] or
                contract['platform'] != candidate['platform'] or
                contract['tag'] != candidate['tag'] or
                execution['run_id'] != str(candidate['run_id']) or
                execution['run_attempt'] != str(candidate['run_attempt'])):
            raise ValueError('archive belongs to a different producer')
    except (KeyError, TypeError) as error:
        raise ValueError('incomplete native evidence archive') from error
    return result
