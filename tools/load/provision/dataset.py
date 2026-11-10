"""Seed only the freshly owned QA database, preserving real API auth limits."""
import uuid
import re
from tools.load.guard.ownership import owned, query, verify_marker,HUMAN_USERS
from .request import api


def validate_count(count):
    if type(count) is not int or not 1 <= count <= 100:
        raise ValueError('Profile requires 1..100 synthetic accounts')


def roster_room_count(count, rooms):
    validate_count(count)
    if rooms is None:
        return (count + 19) // 20
    if type(rooms) is not int or not 0 <= rooms <= 20:
        raise ValueError('Roster profile requires 0..20 rooms')
    return rooms


def account_rows(count):
    validate_count(count)
    return [dict(Login=f'qa_load_{index:03}', ID=str(uuid.uuid4())) for index in range(count)]


def provision(stack, nonce, count, rooms=None):
    room_count = roster_room_count(count, rooms)
    if not re.fullmatch("[a-f0-9]{64}", nonce):
        raise ValueError("Invalid private fixture nonce")
    owned(stack, 'db')
    if query(stack, "SELECT current_database(), count(*) "+HUMAN_USERS) != 'qa|1':
        raise ValueError('Provisioning requires a new single-admin disposable database')
    rows = account_rows(count)
    values = ','.join(f"('{row['ID']}'::uuid,'{row['Login']}')" for row in rows)
    query(stack, "BEGIN; CREATE TABLE qa_load_fixture(owner text,nonce text,account_count integer);"
          f"INSERT INTO qa_load_fixture VALUES ('{stack.owner}','{nonce}',{count});"
          "INSERT INTO users(id,login,display_name,role,password_hash) "
          f"SELECT seed.id,seed.login,seed.login,'MEMBER',admin.password_hash FROM (VALUES {values}) "
          "seed(id,login) CROSS JOIN users admin WHERE admin.login='qa_admin';COMMIT;")
    verify_marker(stack, nonce, count)
    client = api(stack)
    category = client('/admin/categories', 'POST', dict(name='LoadLab'), 201)
    create = lambda name, kind: client('/admin/categories/'+category['id']+'/channels',
                                      'POST', dict(name=name, kind=kind), 201)['id']
    private_dm = client('/direct-messages', 'POST', dict(participant_id=rows[0]['ID']), 201)['id']
    text = create('LoadText', 'TEXT')
    voice = [create(f'LoadVoice{index}', 'VOICE') for index in range(room_count)]
    for row in rows:
        row['Password'] = stack.password
    return dict(Text=text, Voice=voice, Accounts=rows, PrivateDM=private_dm)
