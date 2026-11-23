import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'clients/flutter/packages/flutter_webrtc/third_party'
CMAKE = shutil.which('cmake') or str(Path(os.environ['ProgramFiles(x86)']) /
    'Microsoft Visual Studio/2022/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe')


class WindowsSdkCacheTests(unittest.TestCase):
    def fixture(self, directory):
        base = Path(directory)
        source = base / 'source'
        source.mkdir()
        shutil.copy2(SOURCE / 'CMakeLists.txt', source / 'CMakeLists.txt')
        if (SOURCE / 'cmake').exists():
            shutil.copytree(SOURCE / 'cmake', source / 'cmake')
        releases = base / 'releases'
        for version in ['old', 'new']:
            folder = releases / version
            folder.mkdir(parents=True)
            with zipfile.ZipFile(folder / 'libwebrtc-win-x64-release.zip', 'w') as archive:
                archive.writestr('libwebrtc/include/rtc_desktop_device.h', 'fixture')
                archive.writestr('libwebrtc/lib/libwebrtc.dll', version)
                archive.writestr('libwebrtc/lib/libwebrtc.dll.lib', version)
        digest = hashlib.sha256((releases / 'new/libwebrtc-win-x64-release.zip').read_bytes()).hexdigest()
        (source / 'libwebrtc_version.ini').write_text(
            f'binary_version = old\nwindows_binary_version = new\nwindows_sha256 = {digest}\n'
            f'download_url = {releases.as_uri()}\n', encoding='utf-8')
        cached = source / 'downloads'
        cached.mkdir()
        shutil.copy2(releases / 'old/libwebrtc-win-x64-release.zip', cached / 'libwebrtc-win-x64-release.zip')
        stale = source / 'libwebrtc/lib'
        stale.mkdir(parents=True)
        (stale / 'libwebrtc.dll').write_text('old', encoding='utf-8')
        (base / 'CMakeLists.txt').write_text('''cmake_minimum_required(VERSION 3.20)
project(SdkCacheRegression NONE)
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SIZEOF_VOID_P 8)
include("${CMAKE_CURRENT_SOURCE_DIR}/source/CMakeLists.txt")
if(NOT DEFINED LIBWEBRTC_SDK_DIR)
  set(LIBWEBRTC_SDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/source/libwebrtc")
endif()
file(READ "${LIBWEBRTC_SDK_DIR}/lib/libwebrtc.dll" contents)
if(NOT contents STREQUAL "new")
  message(FATAL_ERROR "stale SDK selected instead of pinned Windows version")
endif()
''', encoding='utf-8')
        return base, source

    def configure(self, base):
        generator = ['-G', 'Visual Studio 17 2022', '-A', 'x64'] if os.name == 'nt' else ['-G', 'Unix Makefiles']
        return subprocess.run([CMAKE, '-S', str(base), '-B', str(base / 'build'), *generator], capture_output=True, text=True)

    def test_windows_pin_ignores_legacy_cached_archive_and_sdk(self):
        with tempfile.TemporaryDirectory(prefix='boohta-sdk-') as directory:
            base, source = self.fixture(directory)
            result = self.configure(base)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((source / 'libwebrtc/lib/libwebrtc.dll').read_text(), 'old')

    def test_bad_cached_digest_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='boohta-sdk-') as directory:
            base, source = self.fixture(directory)
            manifest = source / 'libwebrtc_version.ini'
            content = manifest.read_text()
            digest = content.split('windows_sha256 = ')[1].splitlines()[0]
            manifest.write_text(content.replace(digest, '0' * 64))
            current = source / 'downloads/new'
            current.mkdir()
            shutil.copy2(base / 'releases/new/libwebrtc-win-x64-release.zip', current)
            result = self.configure(base)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('SHA256', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
