"""Exact batch ports, isolated native storage namespace and labelled cleanup."""
import re
from tools.qa.client_lifecycle.services import remove_owned
PORTS={'https':5060,'api':5061,'tempo':5062,'sfu_http':5063,'sfu_tcp':5064,'sfu_udp':5065}

def namespace(suffix):
    if not re.fullmatch('[a-f0-9]{16}',suffix):raise ValueError('Owned QA namespace suffix required')
    return 'ru.boohtacord.localqa.qa98325.'+suffix

def cleanup(resources,owner):
    if not re.fullmatch('qa98325-[a-f0-9]{16}',owner):raise ValueError('Foreign QA owner')
    errors=[]
    for kind,name in list(reversed(resources)):
        try:remove_owned(name,owner,kind);resources.remove((kind,name))
        except Exception as error:errors.append({'kind':kind,'error_type':type(error).__name__})
    return errors

def output_name(value):
    if not re.fullmatch(r'qa[0-9]{3,8}-[0-9]{8}',value):raise ValueError('Owned QA output name required')
    return value

def backend_arguments(args,original,replacement):
    if tuple(args[:2])!=('docker','build'):return tuple(args)
    values=list(args)
    if '--file' not in values:raise ValueError('Unexpected Docker build')
    index=values.index('--file')+1
    if values[index]!=str(original)+'/Dockerfile' or values[-1]!=str(original):raise ValueError('Foreign Docker build context')
    values[index]=str(replacement)+'/Dockerfile';values[-1]=str(replacement)
    return tuple(values)

def observation_poll_count(receiver):
    if not isinstance(receiver,bool):raise ValueError('Explicit bounded receiver workflow required')
    return 1200 if receiver else 720
