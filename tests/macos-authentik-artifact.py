#!/usr/bin/env python3
"""Audit ONE fixed candidate release. Never installs/registers/runs its payload.
Artifact identity is NOT proof of external-Key UX, recovery or production license.
"""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile

VERSION = '0.73.0'
SHA256 = '37aaed47183fa20bc903f1358e33af4f5b7a866be19b4bcacca44660bf8fff67'
TEAM = '232G855Y8N'
APP = 'io.goauthentik.platform.agent'
EXTENSION = 'io.goauthentik.platform.psso'
SOURCE_REF = 'c17da2e00f028bb27086edb7974df6c63b27f84b'  # Tag reference, NOT source/binary rebuild proof.

def checked(command):
    return subprocess.run(command, capture_output=True, text=True, check=True, timeout=60)

def audit(package):
    with package.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != SHA256:
        raise ValueError('Candidate checksum mismatch; rejected BEFORE parsing or native tools.')
    signature = checked(['/usr/sbin/pkgutil', '--check-signature', str(package)])
    if ('signed by a developer certificate issued by Apple for distribution' not in signature.stdout
            or f'Developer ID Installer: Authentik Security Inc. ({TEAM})' not in signature.stdout
            or 'Notarization: trusted by the Apple notary service' not in signature.stdout):
        raise ValueError('Installer signing/notarization verification not established; no fallback.')
    with tempfile.TemporaryDirectory(prefix='flakes-authentik-audit-') as temporary:
        expanded = Path(temporary) / 'expanded'
        checked(['/usr/sbin/pkgutil', '--expand-full', str(package), str(expanded)])
        app = expanded / 'agent.pkg/Payload/authentik Agent.app'
        extension = app / 'Contents/PlugIns/PSSO.appex'
        if not app.resolve(strict=True).is_relative_to(expanded.resolve(strict=True)):
            raise ValueError('Unexpected payload path')
        bundle_architectures = {}
        for bundle, identifier in ((app, APP), (extension, EXTENSION)):
            info = plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
            if info.get('CFBundleIdentifier') != identifier or info.get('CFBundleShortVersionString') != VERSION:
                raise ValueError('Unexpected bundle identity/version')
            requirement = f'anchor apple generic and identifier "{identifier}" and certificate leaf[subject.OU] = "{TEAM}"'
            checked(['/usr/bin/codesign', '--verify', '--strict', '-R=' + requirement, str(bundle)])
            executable = bundle / 'Contents/MacOS' / info['CFBundleExecutable']
            architectures = checked(['/usr/bin/lipo', '-archs', str(executable)]).stdout.split()
            if architectures != ['arm64']:
                raise ValueError('Unexpected architecture; candidate is ARM64-only, not Intel accepted.')
            bundle_architectures[identifier] = architectures
        checked(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)])
        ext_info = plistlib.loads((extension / 'Contents/Info.plist').read_bytes())
        if ext_info.get('NSExtension', {}).get('NSExtensionPointIdentifier') != 'com.apple.AppSSO.idp-extension':
            raise ValueError('Unexpected extension point')
    return {
        'candidate': 'authentik-platform', 'version': VERSION, 'sha256': SHA256,
        'source_tag_reference': SOURCE_REF, 'source_binary_equivalence_proven': False,
        'application_id': APP, 'extension_id': EXTENSION, 'team_id': TEAM,
        'architectures': bundle_architectures,
        'OpenID_feature_minimum_macos': '27.0',
        'installer_signature_and_notarization_checked': True,
        'application_and_extension_requirements_checked': True,
        'payload_executed': False, 'installer_scripts_executed': False,
        'installed_or_registered': False, 'native_unlock_verified': False,
        'deployment_approved': False,
        'blockers': ['external-key-no-pin-no-click-one-touch UX untested',
                     'independent password/Touch-ID and offline recovery untested',
                     'PSSO EE production subscription terms require review',
                     'upstream pre-alpha warning; no production-readiness acceptance',
                     'no IdP/MDM registration or policy approval'],
        'trust_note': 'Hash pins bytes; Apple trust/revocation/notarization are checked by this build host, not timeless guarantees.',
    }

if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: macos-authentik-artifact.py FIXED-PKG NEW-REPORT-JSON')
    report = Path(sys.argv[2])
    result = audit(Path(sys.argv[1]).resolve(strict=True))
    with report.open('x') as stream:
        json.dump(result, stream, indent=2, sort_keys=True)
        stream.write('\n')
    print('PASS: fixed candidate artifact ONLY; no payload executed, no native-unlock acceptance or installation.')
