"""Fetch pinned official updater SDKs; no floating latest or executable scripts."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT=Path(__file__).resolve().parents[3]
SDK={
 'macos':('https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz','c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c'),
 'windows':('https://github.com/velopack/velopack/releases/download/1.2.161/velopack_libc_1.2.161.zip','31de8f2cf05a47bd5328a9f98b0c41aec1582156f6075f1058b26941f7f17c20'),
}

def prepare(platform):
 url,digest=SDK[platform]
 destination=ROOT/'clients/flutter'/platform/'Updaters'
 marker=destination/'sdk.sha256'
 required = ['Sparkle.framework/Sparkle', 'Sparkle.framework/Headers/Sparkle.h'] if platform=='macos' else ['include/Velopack.h','lib/velopack_libc_win_x64_msvc.dll']
 if marker.is_file() and marker.read_text().strip()==digest and all((destination/name).is_file() for name in required):return destination
 destination.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='boohtacord-updater-sdk-') as directory:
  package=Path(directory)/'sdk';hash_value=hashlib.sha256()
  with urllib.request.urlopen(url,timeout=60) as source,package.open('wb') as target:
   total=0
   while block:=source.read(1024*1024):
    total+=len(block)
    if total>64*1024*1024:raise ValueError('SDK exceeds bound')
    hash_value.update(block);target.write(block)
  if hash_value.hexdigest()!=digest:raise ValueError('Pinned updater SDK digest differs')
  if platform=='macos':
   # The exact authenticated SDK contains framework-internal symlinks.
   subprocess.run(['/usr/bin/tar','-xf',str(package),'-C',str(destination)],check=True)
  else:
   with zipfile.ZipFile(package) as archive:
    for name in archive.namelist():
     if name.startswith(('/', '\\')) or '..' in Path(name).parts:raise ValueError('SDK path is invalid')
    archive.extractall(destination)
 marker.write_text(digest+'\n')
 return destination

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('platform',choices=SDK);a=p.parse_args();print(prepare(a.platform))
