"""Compile the small local recovery monitor; it never downloads or runs scripts."""
import plistlib
import subprocess
from pathlib import Path
from tools.ci.native.process import ROOT


def macos():
    output=ROOT/'.out/desktop-recovery/macos/BOOHTACORDRecovery.app'
    binary=output/'Contents/MacOS/BOOHTACORDRecovery'
    binary.parent.mkdir(parents=True,exist_ok=True)
    source=ROOT/'clients/flutter/native/desktop_recovery/macos.m'
    slices=[]
    for architecture in ['arm64','x86_64']:
        target=binary.with_suffix('.'+architecture)
        subprocess.run(['xcrun','clang','-fobjc-arc','-arch',architecture,'-mmacosx-version-min=13.0','-framework','Cocoa','-framework','Security',str(source),'-o',str(target)],check=True)
        slices.append(str(target))
    subprocess.run(['/usr/bin/lipo','-create',*slices,'-output',str(binary)],check=True)
    for target in slices:Path(target).unlink()
    (output/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'ru.boohtacord.updateRecovery','CFBundleExecutable':'BOOHTACORDRecovery','CFBundleName':'BOOHTACORDRecovery','CFBundleVersion':'1','CFBundlePackageType':'APPL','LSBackgroundOnly':True,'LSMinimumSystemVersion':'13.0','CFBundleDocumentTypes':[{'CFBundleTypeName':'BOOHTACORD recovery transaction','CFBundleTypeRole':'Viewer','LSHandlerRank':'None','LSItemContentTypes':['public.folder']}]}))
    subprocess.run(['/usr/bin/codesign','--force','--sign','-',str(output)],check=True)
    return output

if __name__=='__main__':print(macos())
