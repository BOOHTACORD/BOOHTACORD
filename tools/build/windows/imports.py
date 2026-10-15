"""Inspect actual PE loader names before publishing a Windows directory."""
import struct
from pathlib import Path


def required_dlls(file: Path):
    data = file.read_bytes()
    try:
        if data[:2] != b'MZ':
            raise ValueError('Invalid PE image')
        pe = struct.unpack_from('<I', data, 60)[0]
        if data[pe:pe + 4] != b'PE\0\0':
            raise ValueError('Invalid PE signature')
        count = struct.unpack_from('<H', data, pe + 6)[0]
        size = struct.unpack_from('<H', data, pe + 20)[0]
        optional = pe + 24
        magic = struct.unpack_from('<H', data, optional)[0]
        if count > 96 or magic not in (0x10b, 0x20b):
            raise ValueError('Invalid PE sections')
        directory = optional + (112 if magic == 0x20b else 96) + 8
        rva, length = struct.unpack_from('<II', data, directory)
        if not rva:
            return []
        if length > 65536:
            raise ValueError('Invalid PE imports')
        sections = [struct.unpack_from('<4I', data, optional + size + 40 * i + 8)
                    for i in range(count)]

        def locate(address):
            for virtual_size, start, raw_size, offset in sections:
                if start <= address < start + min(virtual_size, raw_size):
                    result = offset + address - start
                    if result < len(data):
                        return result
            raise ValueError('Invalid PE import address')

        cursor = locate(rva)
        result = []
        for _ in range(256):
            if len(data[cursor:cursor + 20]) != 20:
                raise ValueError('Truncated PE imports')
            if not any(data[cursor:cursor + 20]):
                return result
            start = locate(struct.unpack_from('<I', data, cursor + 12)[0])
            end = data.find(b'\0', start, start + 260)
            if end < 0:
                raise ValueError('Invalid PE import name')
            name = data[start:end].decode('ascii')
            if '/' in name or '\\' in name or not name.lower().endswith('.dll'):
                raise ValueError('Invalid PE import name')
            result.append(name)
            cursor += 20
        raise ValueError('Too many PE imports')
    except (struct.error, UnicodeError) as error:
        raise ValueError('Invalid PE image') from error


def verify_runtime(release: Path, system_directory: Path):
    local = {file.name.lower(): file for file in release.iterdir() if file.is_file()}
    system = {file.name.lower() for file in system_directory.iterdir() if file.is_file()}
    pending = ['boohtacord_desktop.exe', 'boohtacordrecovery.exe']
    visited = set()
    while pending:
        name = pending.pop()
        if name in visited:
            continue
        visited.add(name)
        if name not in local:
            raise ValueError('Missing Windows loader dependency: ' + name)
        for imported in required_dlls(local[name]):
            dependency = imported.lower()
            if name == 'boohtacordrecovery.exe' and dependency.startswith(('vcruntime', 'msvcp')):
                raise ValueError('Recovery monitor must use the static CRT')
            if dependency.startswith(('api-ms-win-', 'ext-ms-win-')):
                continue  # Windows API-set contracts are resolved by the OS loader.
            if dependency in local:
                pending.append(dependency)
            elif dependency not in system:
                raise ValueError('Missing Windows loader dependency: ' + dependency)
