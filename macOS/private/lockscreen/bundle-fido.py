"""Copy fixed Nix FIDO dependency closure into a sandbox-readable bundle.
Public code only. Reject unknown loader paths/colliding dependency basenames.
"""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(sys.argv[2])
root.mkdir(parents=True, exist_ok=True)
seen, names = {}, {}


def run(*args):
    return subprocess.check_output(args, text=True)


def copy(source):
    source = Path(source).resolve(strict=True)
    if source in seen:
        return seen[source]
    name = source.name
    assert name not in names or names[name] == source, name
    names[name] = source
    target = root / name
    seen[source] = target
    shutil.copyfile(source, target)
    target.chmod(0o755)
    for line in run('otool', '-L', str(source)).splitlines()[1:]:
        dependency = line.strip().split(' (', 1)[0]
        if dependency.startswith('/nix/store/'):
            if Path(dependency).resolve() == source:
                continue
            bundled = copy(dependency)
            run('install_name_tool', '-change', dependency, '@loader_path/' + bundled.name, str(target))
        elif not dependency.startswith(('/usr/lib/', '/System/Library/')):
            raise RuntimeError('Unresolved non-system dependency: ' + dependency)
    run('install_name_tool', '-id', '@loader_path/' + name, str(target))
    run('/usr/bin/codesign', '--force', '--sign', '-', '--timestamp=none', str(target))
    return target


copy(sys.argv[1])
worker = Path(sys.argv[3])
for line in run('otool', '-L', str(worker)).splitlines()[1:]:
    dependency = line.strip().split(' (', 1)[0]
    if dependency.startswith('/nix/store/'):
        bundled = copy(dependency)
        run('install_name_tool', '-change', dependency,
            '@loader_path/../Frameworks/' + bundled.name, str(worker))
    elif not dependency.startswith(('/usr/lib/', '/System/Library/')):
        raise RuntimeError('Unresolved worker dependency: ' + dependency)
assert '/nix/store/' not in '\n'.join(run('otool', '-L', str(worker)).splitlines()[1:])
for library in seen.values():
    linkage = run('otool', '-L', str(library))
    assert '/nix/store/' not in '\n'.join(linkage.splitlines()[1:]), linkage
    run('/usr/bin/codesign', '--verify', '--strict', str(library))
