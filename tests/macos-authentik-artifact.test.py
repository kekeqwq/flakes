#!/usr/bin/env python3
"""Audit fail-closed unit tests: mocks every native tool, executes NO payload."""
import importlib.util
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
from unittest.mock import patch

sys.dont_write_bytecode = True
source = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).with_name('macos-authentik-artifact.py')
spec = importlib.util.spec_from_file_location('audit', source)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
package = Path(sys.argv[1]).resolve(strict=True)  # Already downloaded public fixed release.
with tempfile.TemporaryDirectory() as temporary:
    bad = Path(temporary) / 'tampered.pkg'
    bad.write_bytes(b'not the approved artifact')
    with patch.object(audit.subprocess, 'run', side_effect=AssertionError('Native tool called before hash guard')):
        try:
            audit.audit(bad)
        except ValueError:
            pass
        else:
            raise AssertionError('Tampered artifact accepted')
for scenario in ('valid', 'bad-signer', 'wrong-bundle'):
    calls = []
    def fake_run(command, **kwargs):
        calls.append(command)
        assert command[0] in ('/usr/sbin/pkgutil', '/usr/bin/codesign', '/usr/bin/lipo'), command
        text = ''
        if '--check-signature' in command:
            text = 'untrusted' if scenario == 'bad-signer' else (
                'signed by a developer certificate issued by Apple for distribution\n'
                'Developer ID Installer: Authentik Security Inc. (232G855Y8N)\n'
                'Notarization: trusted by the Apple notary service\n')
        elif '--expand-full' in command:
            app = Path(command[-1]) / 'agent.pkg/Payload/authentik Agent.app'
            for bundle, identifier in ((app, audit.APP), (app / 'Contents/PlugIns/PSSO.appex', audit.EXTENSION)):
                (bundle / 'Contents').mkdir(parents=True, exist_ok=True)
                info = {'CFBundleIdentifier': identifier if scenario == 'valid' else 'wrong.bundle',
                        'CFBundleShortVersionString': audit.VERSION, 'CFBundleExecutable': 'NEVER-EXECUTED',
                        'NSExtension': {'NSExtensionPointIdentifier': 'com.apple.AppSSO.idp-extension'}}
                (bundle / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        elif command[0] == '/usr/bin/lipo':
            text = 'arm64\n'
        return subprocess.CompletedProcess(command, 0, text, '')
    with patch.object(audit.subprocess, 'run', side_effect=fake_run):
        try:
            result = audit.audit(package)
        except ValueError:
            assert scenario != 'valid'
        else:
            assert scenario == 'valid'
            assert not any(result[k] for k in ('native_unlock_verified', 'deployment_approved',
                       'installed_or_registered', 'payload_executed', 'installer_scripts_executed'))
    if scenario == 'bad-signer':
        assert len(calls) == 1  # Never unpack after failed signer guard.
print('PASS: checksum/signature/bundle guards; metadata-only success never claims installation or unlock. No native tool/payload executed.')
