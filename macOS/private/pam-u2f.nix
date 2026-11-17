{ pkgs }:
pkgs.runCommand "pam-u2f-apple-pam-${pkgs.pam_u2f.version}"
  {
    nativeBuildInputs = [
      pkgs.darwin.cctools
      pkgs.darwin.sigtool
    ];
  }
  ''
    mkdir -p "$out/lib/security"
    cp ${pkgs.pam_u2f}/lib/security/pam_u2f.so "$out/lib/security/pam_u2f.so"
    chmod u+w "$out/lib/security/pam_u2f.so"
    # sudo supplies an Apple PAM handle. Never hand it to a second OpenPAM.
    install_name_tool -change ${pkgs.pam}/lib/libpam.2.dylib /usr/lib/libpam.2.dylib "$out/lib/security/pam_u2f.so"
    codesign --force --sign - "$out/lib/security/pam_u2f.so"
    otool -L "$out/lib/security/pam_u2f.so" > "$out/linkage.txt"
    grep -F /usr/lib/libpam.2.dylib "$out/linkage.txt"
    ! grep -F ${pkgs.pam}/lib/libpam "$out/linkage.txt"
  ''
