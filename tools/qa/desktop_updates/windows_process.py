"""Inspect and gracefully close only the exact owned native test executable."""
import ctypes
from ctypes import wintypes
import os
import time


def running_at(executable):
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.QueryFullProcessImageNameW.argtypes = [
        wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR,
        ctypes.POINTER(wintypes.DWORD)]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.K32EnumProcesses.argtypes = [ctypes.POINTER(wintypes.DWORD),
                                      wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    process_ids = (wintypes.DWORD * 8192)()
    used = wintypes.DWORD()
    if not kernel.K32EnumProcesses(process_ids, ctypes.sizeof(process_ids),
                                  ctypes.byref(used)):
        raise OSError('Could not inspect owned test processes')
    result = []
    for process_id in process_ids[:used.value // ctypes.sizeof(wintypes.DWORD)]:
        handle = kernel.OpenProcess(0x1000, False, process_id)
        if not handle:
            continue
        try:
            buffer = ctypes.create_unicode_buffer(32768)
            length = wintypes.DWORD(len(buffer))
            if kernel.QueryFullProcessImageNameW(handle, 0, buffer,
                                                ctypes.byref(length)):
                if os.path.normcase(buffer.value) == os.path.normcase(str(executable)):
                    result.append(process_id)
        finally:
            kernel.CloseHandle(handle)
    return result


def close_owned(executable):
    processes = set(running_at(executable))
    user = ctypes.WinDLL('user32', use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]

    @callback_type
    def close(window, _):
        owner = wintypes.DWORD()
        user.GetWindowThreadProcessId(window, ctypes.byref(owner))
        if owner.value in processes:
            user.PostMessageW(window, 0x0010, 0, 0)  # WM_CLOSE, never TerminateProcess.
        return True

    user.EnumWindows(close, 0)
    deadline = time.monotonic() + 15
    while running_at(executable) and time.monotonic() < deadline:
        time.sleep(0.25)
    if running_at(executable):
        raise RuntimeError('Owned restored app did not accept graceful close')
