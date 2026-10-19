"""Bounded framework ZIP extraction preserves only internal, non-overlapping links."""
from pathlib import PurePosixPath
import posixpath
import shutil
import stat
import zipfile
from .contract import require


def extract(archive,destination):
    destination.mkdir(exist_ok=False);root=destination.resolve()
    with zipfile.ZipFile(archive) as stream:
        rows=stream.infolist();require(0<len(rows)<=20_000);seen=set();links={};total=0
        for row in rows:
            name=row.filename.rstrip('/');path=PurePosixPath(name)
            require(name and not path.is_absolute() and '..' not in path.parts and '\\' not in name and ':' not in name
                    and path.parts[0] in ('WebRTC.framework','__MACOSX') and name.casefold() not in seen)
            seen.add(name.casefold());total+=row.file_size;require(total<=2_000_000_000)
            mode=row.external_attr>>16;require(stat.S_IFMT(mode) in (0,stat.S_IFREG,stat.S_IFDIR,stat.S_IFLNK))
            if stat.S_ISLNK(mode):
                require(row.file_size<=1024 and path.parts[0]=='WebRTC.framework')
                target=stream.read(row).decode('utf-8');normalized=posixpath.normpath(str(path.parent/target))
                require(not target.startswith('/') and '\\' not in target and '\0' not in target
                        and normalized.startswith('WebRTC.framework/'))
                links[name]=target
        for row in rows:
            name=row.filename.rstrip('/');path=PurePosixPath(name)
            require(not any(str(parent) in links for parent in path.parents))
            if name in links:continue
            target=root.joinpath(*path.parts)
            if row.is_dir():target.mkdir(parents=True,exist_ok=True)
            else:
                target.parent.mkdir(parents=True,exist_ok=True)
                with stream.open(row) as source,target.open('xb') as output:shutil.copyfileobj(source,output)
                target.chmod(0o755 if row.external_attr>>16 & 0o111 else 0o644)
        for name,target in links.items():
            path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.symlink_to(target)
        for name in links:require((root/name).resolve(strict=True).is_relative_to(root/'WebRTC.framework'))
    return root/'WebRTC.framework'
