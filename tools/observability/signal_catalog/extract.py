"""Small source inventory, not a replacement for inspecting stored telemetry."""
import re

SDK = re.compile(r'\.(?P<kind>(?:Int64|Float64)(?:Observable)?(?:Counter|UpDownCounter|Histogram|Gauge))\s*\(')
PRIVATE = re.compile(r'prometheus\.New(?P<kind>Counter|Gauge|Histogram|Summary)(?:Vec)?\s*\(')


def balanced(source, start):
    """Return one Go call, respecting nested calls and quoted strings."""
    depth, quoted, escaped = 0, False, False
    for pos in range(start, len(source)):
        char = source[pos]
        if quoted:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                return source[start:pos + 1]
    raise ValueError('unterminated instrument constructor')


def prometheus_name(name, kind, unit):
    name = re.sub(r'[^a-zA-Z0-9_:]', '_', name)
    suffix = {'s': 'seconds', 'ms': 'milliseconds', 'By': 'bytes'}.get(unit)
    if suffix and not name.endswith('_' + suffix):
        name += '_' + suffix
    if 'Counter' in kind and 'UpDownCounter' not in kind and not name.endswith('_total'):
        name += '_total'
    return name


def instruments(source):
    result = []
    for match in SDK.finditer(source):
        call = balanced(source, match.end() - 1)
        literal = re.match(r'\(\s*"([^"]+)"', call)
        if not literal:
            raise ValueError('SDK instrument name is not inventoried: ' + call[:80])
        name = literal.group(1)
        dynamic = call[literal.end():].lstrip().startswith('+')
        unit = re.search(r'WithUnit\("([^"]+)"\)', call)
        buckets = re.search(r'WithExplicitBucketBoundaries\(([^)]+)\)', call)
        result.append({'source_name': name, 'type': match['kind'], 'unit': unit.group(1) if unit else '1',
                       'transport': 'OTLP', 'labels': [], 'dynamic': dynamic,
                       'line': source.count('\n', 0, match.start()) + 1,
                       'buckets': buckets.group(1).strip() if buckets else 'SDK default / explicit definition map'})
    for match in PRIVATE.finditer(source):
        call = balanced(source, match.end() - 1)
        name = re.search(r'Name:\s*"([^"]+)"', call)
        if not name:
            raise ValueError('private instrument name is not inventoried: ' + call[:80])
        labels = re.search(r'\[\]string\s*\{([^}]+)\}', call)
        if labels:
            labels = re.findall(r'"([^"]+)"', labels.group(1))
        else:
            labels = []
            if re.search(r'},\s*labels\s*\)', call):
                declaration = re.search(r'labels\s*:?=\s*\[\]string\s*\{([^}]+)\}', source)
                if declaration:
                    labels = re.findall(r'"([^"]+)"', declaration.group(1))
        result.append({'source_name': name.group(1), 'type': match['kind'], 'unit': native_unit(name.group(1)),
                       'transport': 'private-prometheus', 'labels': labels, 'dynamic': False,
                       'line': source.count('\n', 0, match.start()) + 1,
                       'buckets': 'prometheus defaults' if 'Buckets:' not in call else re.search(r'Buckets:\s*([^}]+)', call).group(1).strip()})
    for match in re.finditer(r'prometheus\.NewDesc\(\s*"([^"]+)"', source):
        call = balanced(source, source.index('(', match.start()))
        labels = re.search(r'\[\]string\s*\{([^}]+)\}', call)
        result.append({'source_name': match.group(1), 'type': 'CustomCollector', 'unit': native_unit(match.group(1)),
                       'transport': 'private-prometheus', 'labels': re.findall(r'"([^"]+)"', labels.group(1)) if labels else [],
                       'dynamic': source[match.end():].lstrip().startswith('+'), 'line': source.count('\n', 0, match.start()) + 1, 'buckets': 'not applicable'})
    return result


def native_unit(name):
    if name.endswith('_total'):
        name = name[:-6]
    for suffix, unit in (('_seconds', 's'), ('_milliseconds', 'ms'), ('_ms', 'ms'), ('_bytes', 'By'), ('_kbps', 'kbit/s'), ('_percent', '%'), ('_fps', 'frame/s')):
        if name.endswith(suffix):
            return unit
    return '1'


def expand(item, source):
    if not item.pop('dynamic'):
        return [item]
    if item['source_name'] == 'boohtacord_media_':
        section = source.split('definitions := map[string][]float64{', 1)[1].split('for name, buckets', 1)[0]
        names = re.findall(r'"([a-z_]+)":', section)
    elif item['source_name'] == 'boohtacord.users.':
        names = re.findall(r'"([a-z_]+)"', re.search(r'names := \[\]string\{([^}]+)\}', source).group(1))
    elif item['source_name'] == 'voice_platform_database_pool_':
        names = re.findall(r'"([a-z_]+)"', re.search(r'for _, name := range \[\]string\{([^}]+)\}', source).group(1))
    else:
        raise ValueError('unknown dynamic instrument family: ' + item['source_name'])
    return [{**item, 'source_name': item['source_name'] + name} for name in names]
