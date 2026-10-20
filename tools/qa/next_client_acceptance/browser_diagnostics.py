"""Strict public schema for synthetic browser failure coordinates and DOM metrics."""
STAGES = {'browser-launch', 'api-ready', 'login', 'fixture-setup', 'reload', 'uploads', 'unread', 'navigation', 'receipt'}
MODULES = {'scenario.mjs', 'fixture.mjs', 'native_browser.mjs', 'uploads.mjs', 'unread.mjs', 'navigation.mjs',
           'cache_acl.mjs', 'navigation_fixture.mjs', 'window_visibility.mjs', 'input_files.mjs', 'revocation_sql.mjs'}
KINDS = {'other', 'timeout', 'navigation-interrupted', 'target-closed', 'page-crashed', 'execution-context-destroyed',
         'protocol-context-missing', 'protocol-error', 'strict-locator', 'frame-detached',
         'ERR_CONNECTION_REFUSED', 'ERR_CONNECTION_CLOSED', 'ERR_CONNECTION_RESET', 'ERR_CONNECTION_TIMED_OUT',
         'ERR_TIMED_OUT', 'ERR_ABORTED', 'ERR_NETWORK_CHANGED', 'ERR_NAME_NOT_RESOLVED', 'ERR_CERT_AUTHORITY_INVALID',
         'ERR_EMPTY_RESPONSE', 'ERR_SSL_PROTOCOL_ERROR'}
SIGNALS = {'SIGHUP', 'SIGINT', 'SIGQUIT', 'SIGILL', 'SIGTRAP', 'SIGABRT', 'SIGBUS', 'SIGFPE', 'SIGKILL', 'SIGSEGV', 'SIGPIPE', 'SIGTERM', 'other'}


def require(condition):
    if not condition: raise ValueError('Invalid finite browser diagnostic')


def integer(value, low=0, high=1_000_000_000):
    return type(value) is int and low <= value <= high


def validate_context(row):
    require(isinstance(row, dict) and type(row.get('schema_version')) is int and row['schema_version'] in (1, 2))
    version=row['schema_version']; fields={'schema_version', 'status', 'stage', 'failure_type', 'frames'}
    if version == 2 and 'capture_failure_kind' in row:
        fields.add('capture_failure_kind')
        require(row['capture_failure_kind'] in KINDS)
    require(set(row) == fields | ({'failure_kind', 'native_process'} if version == 2 else set()))
    require(row['status'] == 'FAIL' and row['stage'] in STAGES | ({'origin-navigation'} if version == 2 else set())
            and row['failure_type'] in {'Error', 'TimeoutError', 'AssertionError'})
    if version == 2:
        require(row['failure_kind'] in KINDS)
        native=row['native_process']
        if native is not None:
            require(isinstance(native, dict) and set(native) == {'browser_connected', 'page_closed', 'exit_code', 'signal'})
            require(type(native['browser_connected']) is bool and type(native['page_closed']) is bool)
            require(native['exit_code'] is None or integer(native['exit_code'], 0, 255))
            require(native['signal'] is None or native['signal'] in SIGNALS)
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
