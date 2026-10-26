"""Finite, repository-scoped capabilities for public product support."""
import re
from datetime import datetime
from uuid import UUID

REPOSITORY='Egkurilov/BOOHTACORD'
ASSET_TAG='boohtacord-support-attachments'
MAX_FILE_BYTES=25_000_000


def require(value):
    if not value:raise ValueError('Support request is invalid')


def hex_value(value,length):return isinstance(value,str) and re.fullmatch('[a-f0-9]{%d}'%length,value) is not None


def text(value,maximum,empty=False):
    require(isinstance(value,str) and (empty or bool(value)) and len(value)<=maximum and '\x00' not in value)
    return value


def integer(value,maximum=2**53-1):
    require(type(value) is int and 0<value<=maximum)
    return value


def publication(value,version):
    fields={'operation_id','conversation','body','consent_version','files'}
    # Old installations and already accepted jobs remain readable during rollout.
    require(isinstance(value,dict) and set(value) in (fields,fields|{'user_id'}))
    require(hex_value(value['operation_id'],32) and hex_value(value['conversation'],32))
    if 'user_id' in value:
        require(isinstance(value['user_id'],str))
        author=UUID(value['user_id']);require(author.int!=0 and str(author)==value['user_id'])
    require(type(value['consent_version']) is int and value['consent_version']==integer(version))
    text(value['body'],8000,empty=True)
    files=value['files'];require(isinstance(files,list) and len(files)<=10)
    require(bool(value['body']) or bool(files))
    for item in files:
        require(isinstance(item,dict) and set(item)=={'name','size','sha256'})
        text(item['name'],128)
        require(not any(c in item['name'] for c in ('/','\\','\r','\n')) and item['name'] not in ('.','..'))
        require(type(item['size']) is int and 0<=item['size']<=MAX_FILE_BYTES);require(hex_value(item['sha256'],64))
    return value


def reply_allowed(permission,forwarded):
    return permission in ('write','maintain','admin') and forwarded is False


def broker_request(value):
    require(isinstance(value,dict));operation=value.get('operation')
    fields={
        'repository':set(), 'asset_release':set(),
        'create_issue':{'title','body'},'create_comment':{'issue','body'},
        'comments':{'since','page'},'issue_comments':{'issue','page'},
        'permission':{'login'},'find_operation':{'marker'},'issue':{'issue'},
        'upload_asset':{'release','blob','name','size','sha256'},
    }
    require(operation in fields and set(value)==fields[operation]|{'operation'})
    if operation=='create_issue':text(value['title'],120);text(value['body'],64000)
    if operation=='create_comment':integer(value['issue']);text(value['body'],64000)
    if operation=='issue':integer(value['issue'])
    if operation=='issue_comments':integer(value['issue']);integer(value['page'],100)
    if operation=='comments':
        text(value['since'],40);stamp=datetime.fromisoformat(value['since'].replace('Z','+00:00'))
        require(stamp.tzinfo is not None);integer(value['page'],100)
    if operation=='permission':require(isinstance(value['login'],str) and re.fullmatch('[A-Za-z0-9][A-Za-z0-9-]{0,38}',value['login']))
    if operation=='find_operation':require(hex_value(value['marker'],32))
    if operation=='upload_asset':
        integer(value['release']);require(type(value['size']) is int and 0<=value['size']<=MAX_FILE_BYTES)
        require(hex_value(value['blob'],32) and hex_value(value['sha256'],64))
        require(isinstance(value['name'],str) and re.fullmatch('[a-zA-Z0-9_.-]{1,180}',value['name']) and value['name'] not in ('.','..'))
    return value
