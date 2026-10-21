"""Fixed retention floor and exact release-owned image eligibility."""
import re
from tools.release.bundle.manifest import require


def retained(rows,current,previous,referenced,keep=10):
    require(type(keep) is int and keep>=10,'Keep at least ten releases')
    known={r['revision'] for r in rows}
    require(current in known and previous in known,'Current and rollback signed manifests are required')
    return {r['revision'] for r in sorted(rows,key=lambda r:(r['time'],r['revision']),reverse=True)[:keep]}|{current,previous}|set(referenced)


def reference(service,digest):
    require(service in ('api','web') and re.fullmatch('sha256:[a-f0-9]{64}',digest),'Invalid release image')
    return 'voice-platform-'+service+'@'+digest


def image_candidates(rows,keep,images,in_use):
    protected=set(in_use);protected_refs=set()
    for row in rows:
        if row['revision'] in keep:
            protected_refs.update(reference(s,row['manifest']['components'][s]['index_digest']) for s in ('api','web'))
    protected.update(images[r] for r in protected_refs if r in images)
    candidates=set()
    for row in rows:
        if row['revision'] not in keep:
            for service in ('api','web'):
                ref=reference(service,row['manifest']['components'][service]['index_digest'])
                if ref in images and ref not in protected_refs and images[ref] not in protected:candidates.add(ref)
    return sorted(candidates)
