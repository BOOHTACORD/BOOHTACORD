"""Keep the caller's isolated Docker context and pinned native SDKs."""
import os
from pathlib import Path


def native_environment(values):
    result = dict(values)
    sdk = result.get('ANDROID_SDK_ROOT') or result.get('ANDROID_HOME') or '/opt/homebrew/share/android-commandlinetools'
    result.setdefault('ANDROID_HOME', sdk)
    result.setdefault('ANDROID_SDK_ROOT', sdk)
    result.setdefault('JAVA_HOME', '/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home')
    result.setdefault('DOCKER_CONTEXT', 'colima-boohtacord-qa')
    paths = [str(Path(sdk) / 'platform-tools')]
    if result.get('FLUTTER_ROOT'):
        paths.append(str(Path(result['FLUTTER_ROOT']) / 'bin'))
    paths.append(result.get('PATH', os.defpath))
    result['PATH'] = os.pathsep.join(paths)
    return result
