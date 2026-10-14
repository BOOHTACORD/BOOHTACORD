"""Retain Microsoft's installed x64 CRT for a per-user app-local distribution."""
import os
from pathlib import Path
import re
import shutil
import subprocess


def retain_runtime(destination: Path, *, visual_studio=None):
    if visual_studio is None:
        installer=Path(os.environ['ProgramFiles(x86)'])/'Microsoft Visual Studio/Installer/vswhere.exe'
        if not installer.is_file():raise RuntimeError('Visual Studio redistributable locator is unavailable')
        location=subprocess.check_output([str(installer),'-latest','-products','*','-requires','Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-property','installationPath'],text=True).strip()
        if not location:raise RuntimeError('Visual Studio redistributable installation is unavailable')
        visual_studio=Path(location)
    candidates=list(Path(visual_studio).glob('VC/Redist/MSVC/*/x64/Microsoft.VC143.CRT'))
    if not candidates:raise RuntimeError('Visual C++ x64 redistributable files are unavailable')
    candidates.sort(key=lambda p:tuple(map(int,re.findall(r'\d+',p.parents[1].name))),reverse=True)
    folder=candidates[0]
    required={'msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll'}
    files=list(folder.glob('*.dll'))
    if not required <= {p.name.lower() for p in files}:raise RuntimeError('Visual C++ x64 redistributable is incomplete')
    for file in files:shutil.copyfile(file,Path(destination)/file.name)
