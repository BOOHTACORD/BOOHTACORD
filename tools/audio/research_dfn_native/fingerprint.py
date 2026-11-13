"""Fingerprint synthetic processing of a hash-verified Windows research DLL."""
import argparse
import ctypes
import hashlib
import math
import os
from pathlib import Path

from .prepare import MODEL_SHA


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def run_frames(process, state, count):
    if not 1 <= count <= 10000:
        raise ValueError('Invalid fixture frame count')
    frame_type = ctypes.c_float * 480
    source, output = frame_type(), frame_type()
    result = hashlib.sha256()
    peak = 0.0
    for frame in range(count):
        for i in range(480):
            source[i] = (((frame * 480 + i) * 40503) % 65536 - 32768) / 262144.0
        if process(state, source, output, 480) != 0 or not all(math.isfinite(x) for x in output):
            raise ValueError('Research processing failed or returned nonfinite audio')
        peak = max(peak, max(abs(x) for x in output))
        result.update(bytes(output))
    if peak <= 1e-8:
        raise ValueError('Research processing returned only silence')
    return result.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dll', type=Path, required=True)
    parser.add_argument('--dll-sha256', required=True)
    parser.add_argument('--model', type=Path, required=True)
    args = parser.parse_args()
    if os.name != 'nt' or digest(args.dll) != args.dll_sha256.lower() or digest(args.model) != MODEL_SHA:
        raise ValueError('Platform or research artifact checksum mismatch')
    library = ctypes.CDLL(str(args.dll.resolve()), winmode=0x1100)
    create, process, release = library.research_create, library.research_process, library.research_free
    create.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_void_p)]
    create.restype = ctypes.c_int
    process.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.POINTER(ctypes.c_float), ctypes.c_size_t]
    process.restype = ctypes.c_int
    release.argtypes = [ctypes.c_void_p]
    release.restype = ctypes.c_int
    model = str(args.model.resolve()).encode('utf-8')
    path_buffer, state = ctypes.create_string_buffer(model), ctypes.c_void_p()
    if create(path_buffer, len(model), ctypes.byref(state)) != 0 or not state.value:
        raise ValueError('Research model initialization failed')
    try:
        result = run_frames(process, state, 220)
    finally:
        if release(state) != 0:
            raise ValueError('Research model cleanup failed')
    print('synthetic_float32_sha256=' + result)


if __name__ == '__main__':
    main()
