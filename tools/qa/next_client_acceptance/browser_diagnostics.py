"""Strict public schema for synthetic browser failure coordinates and DOM metrics."""
STAGES = {'browser-launch', 'api-ready', 'login', 'fixture-setup', 'reload', 'uploads', 'unread', 'navigation', 'receipt'}
MODULES = {'scenario.mjs', 'fixture.mjs', 'native_browser.mjs', 'uploads.mjs', 'unread.mjs', 'navigation.mjs',
           'cache_acl.mjs', 'navigation_fixture.mjs', 'window_visibility.mjs', 'input_files.mjs', 'revocation_sql.mjs'}


def require(condition):
    if not condition: raise ValueError('Invalid finite browser diagnostic')


def integer(value, low=0, high=1_000_000_000):
    return type(value) is int and low <= value <= high


def validate_context(row):
    require(isinstance(row, dict) and set(row) == {'schema_version', 'status', 'stage', 'failure_type', 'frames'})
    require(type(row['schema_version']) is int and row['schema_version'] == 1 and row['status'] == 'FAIL')
    require(row['stage'] in STAGES and row['failure_type'] in {'Error', 'TimeoutError', 'AssertionError'})
    require(isinstance(row['frames'], list) and len(row['frames']) <= 8)
    for frame in row['frames']:
        require(isinstance(frame, dict) and set(frame) == {'module', 'line', 'column'})
        require(frame['module'] in MODULES and integer(frame['line'], 1, 999999) and integer(frame['column'], 1, 999999))
    return row


def validate_dom(row):
    flags={'main_history_visible', 'context_visible', 'saved_position_context'}
    counts={'main_rendered_rows', 'main_reply_previews', 'context_rows'}
    require(isinstance(row, dict) and set(row) == flags | counts | {'viewport'})
    require(all(type(row[key]) is bool for key in flags) and all(integer(row[key]) for key in counts))
    viewport=row['viewport']
    if viewport is not None:
        require(isinstance(viewport, dict) and set(viewport) == {'scrollTop', 'scrollHeight', 'clientHeight'})
        require(integer(viewport['scrollTop'], -1_000_000_000) and integer(viewport['scrollHeight']) and integer(viewport['clientHeight']))
    return row
