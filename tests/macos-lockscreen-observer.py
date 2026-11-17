#!/usr/bin/env python3
"""Rollback logic only: redirect ALL policy/state/GC paths into a private fixture.
No real PAM changes, authentication, privileged command, or screen locking.
"""
import os
from pathlib import Path
import pty
import subprocess
import sys
import tempfile

program = Path(sys.argv[1]).read_text()
for case in ("normal", "partial-install", "signal", "concurrent-edit"):
    with tempfile.TemporaryDirectory(prefix="flakes-observer-fixture-") as directory:
        root = Path(directory)
        pam, stubs, gc = (root / x for x in ("pam", "stubs", "gc"))
        for path in (pam, stubs, gc):
            path.mkdir()
        original = b"# Native fixture only\nauth required pam_opendirectory.so\n"
        names = "screensaver screensaver_aks screensaver_ctk screensaver_la screensaver_new screensaver_new_aks screensaver_new_ctk screensaver_new_la".split()
        for name in names:
            (pam / name).write_bytes(original)

        def stub(name, text):
            p = stubs / name
            p.write_text("#!" + sys.executable + "\n" + text)
            p.chmod(0o755)

        stub("id", "print(0)\n")
        stub("stat", "import sys\nprint('0:700' if sys.argv[2]=='%u:%Lp' else '0:0:644')\n")
        stub("codesign", "pass\n")
        stub("log", "pass\n")
        stub("install", """import os, sys
args = sys.argv[1:]
for flag in ('-o', '-g'):
    while flag in args:
        n = args.index(flag)
        del args[n:n+2]
os.execv('/usr/bin/install', ['install'] + args)
""")
        stub("mv", """import os, pathlib, sys
args = sys.argv[1:]
if os.environ['CASE']=='partial-install' and args[-1].endswith('/screensaver_la') and '.flakes-observe.' in args[-2]:
    sys.exit(1)
os.execv('/bin/mv', ['mv'] + args)
""")
        stub("sleep", """import os, pathlib, signal
if os.environ['CASE']=='signal':
    os.kill(os.getppid(), signal.SIGTERM)  # Only our own nonprivileged fixture child.
if os.environ['CASE']=='concurrent-edit':
    with open(os.environ['FIXTURE_PAM']+'/screensaver_new', 'a') as f:
        f.write('# independent change\\n')
""")
        text = program.replace("/etc/pam.d/", str(pam) + "/")
        text = text.replace("/var/run/flakes-lockscreen-observer.expiry", str(root / "expiry"))
        text = text.replace("/var/root/flakes-lockscreen-observer", str(root / "backups"))
        text = text.replace("/nix/var/nix/gcroots/", str(gc) + "/")
        text = text.replace("export PATH=/usr/bin:", f"export PATH={stubs}:/usr/bin:")
        text = text.replace("/usr/bin/codesign", str(stubs / "codesign"))
        text = text.replace("/usr/bin/log show", str(stubs / "log") + " show")
        assert "/etc/pam.d/" not in text
        assert "/var/run/flakes-lockscreen-observer" not in text
        assert "/nix/var/nix/gcroots/" not in text
        fixture = root / "run"
        fixture.write_text(text)
        fixture.chmod(0o700)
        master, slave = pty.openpty()
        try:
            result = subprocess.run(
                [str(fixture), "--observe"], stdin=slave,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                env={**os.environ, "CASE": case, "FIXTURE_PAM": str(pam)},
                timeout=20, text=True,
            )
        finally:
            os.close(slave)
            os.close(master)
        expected = {"normal": 0, "partial-install": 1, "signal": 130, "concurrent-edit": 1}[case]
        assert result.returncode == expected, (case, result.returncode, result.stdout)
        for name in names:
            content = (pam / name).read_bytes()
            if case == "concurrent-edit" and name == "screensaver_new":
                assert content.endswith(b"# independent change\n")
                assert "Not overwriting independently changed" in result.stdout
            else:
                assert content == original, (case, name, result.stdout)
        assert not (root / "expiry").exists()
        assert not list(pam.glob(".flakes-*")), (case, result.stdout)
        assert bool(list(gc.iterdir())) == (case == "concurrent-edit")
        print(f"PASS synthetic {case}: fixture policies restored/preserved as intended")
