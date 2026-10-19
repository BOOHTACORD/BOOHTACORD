"""Validate observed coarse rollout intervals; never infer legacy maintenance time."""
import re

ORDER = ('rollout_started','maintenance_requested','maintenance_enabled','migration_started','migration_completed',
         'services_started','health_started','health_passed','maintenance_disabled','rollout_completed')
INTERVALS = {'rollout_seconds':('rollout_started','rollout_completed'),
             'maintenance_seconds':('maintenance_enabled','maintenance_disabled'),
             'maintenance_request_to_disable_seconds':('maintenance_requested','maintenance_disabled'),
             'admission_enable_seconds':('maintenance_requested','maintenance_enabled'),
             'migration_seconds':('migration_started','migration_completed'),
             'services_to_health_seconds':('services_started','health_passed'),
             'health_seconds':('health_started','health_passed')}


def parse(raw):
    try:
        if not isinstance(raw,str) or len(raw)>8192: raise ValueError
        if not raw: return {'status':'NOT_AVAILABLE_LEGACY','events':[]}
        rows=raw.splitlines()
        if len(rows)!=len(ORDER): raise ValueError
        events=[]
        for name,line in zip(ORDER,rows):
            match=re.fullmatch(re.escape(name)+r' ([0-9]{1,10})',line)
            if not match: raise ValueError
            events.append({'phase':name,'unix_seconds':int(match[1])})
        values={row['phase']:row['unix_seconds'] for row in events}
        if any(a['unix_seconds']>b['unix_seconds'] for a,b in zip(events,events[1:])): raise ValueError
        durations={name:values[end]-values[start] for name,(start,end) in INTERVALS.items()}
        if durations['rollout_seconds']>3600: raise ValueError
        return {'status':'PASS','resolution_seconds':1,'events':events,'durations':durations}
    except Exception:
        raise ValueError('Observed rollout intervals are incomplete or inconsistent') from None


def validate(value):
    try:
        if not isinstance(value,dict): raise ValueError
        if value=={'status':'NOT_AVAILABLE_LEGACY','events':[]}: return value
        if set(value)!={'status','resolution_seconds','events','durations'} or type(value['resolution_seconds']) is not int:
            raise ValueError
        if (not isinstance(value['events'],list) or len(value['events'])!=len(ORDER)
                or not isinstance(value['durations'],dict) or any(type(v) is not int for v in value['durations'].values())): raise ValueError
        for row in value['events']:
            if not isinstance(row,dict) or set(row)!={'phase','unix_seconds'} or type(row['unix_seconds']) is not int: raise ValueError
        raw=''.join(f'{row["phase"]} {row["unix_seconds"]}\n' for row in value['events'])
        if parse(raw)!=value: raise ValueError
        return value
    except Exception:
        raise ValueError('Published rollout intervals differ from observed events') from None
