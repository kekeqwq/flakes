{ pkgs }:
pkgs.runCommand "macos-lockscreen-pam-observer"
  {
    nativeBuildInputs = [
      pkgs.stdenv.cc
      pkgs.darwin.cctools
      pkgs.darwin.sigtool
      pkgs.python3
    ];
  }
  ''
    mkdir -p "$out/lib/security"
    # Nix's SDK omits PAM declarations/stubs. Link with OpenPAM's public ABI,
    # then use the same native-library retargeting as the deployed sudo module.
    cc -Wall -Wextra -Werror -I${pkgs.pam}/include -dynamiclib ${./observer.c} \
      -L${pkgs.pam}/lib -lpam -o "$out/lib/security/observer.so"
    install_name_tool -change ${pkgs.pam}/lib/libpam.2.dylib /usr/lib/libpam.2.dylib "$out/lib/security/observer.so"
    codesign --force --sign - "$out/lib/security/observer.so"
    /usr/bin/codesign --verify --strict "$out/lib/security/observer.so"
    otool -L "$out/lib/security/observer.so" > "$out/linkage.txt"
    grep -F /usr/lib/libpam.2.dylib "$out/linkage.txt"
    ! grep -E '/nix/store/.*(openpam|libpam)' "$out/linkage.txt"
    python3 - "$out/lib/security/observer.so" <<'PY'
    import ctypes as C
    import sys
    p = C.CDLL('/usr/lib/libpam.2.dylib')
    m = C.CDLL(sys.argv[1])
    CB = C.CFUNCTYPE(C.c_int, C.c_int, C.c_void_p, C.c_void_p, C.c_void_p)
    prompts = []
    @CB
    def reject(*args):
        prompts.append(True)
        return 6  # PAM_CONV_ERR; never supply input.
    class Conv(C.Structure):
        _fields_ = [('callback', CB), ('data', C.c_void_p)]
    conv = Conv(reject, None)
    h = C.c_void_p()
    p.pam_start.argtypes = [C.c_char_p, C.c_char_p, C.POINTER(Conv), C.POINTER(C.c_void_p)]
    p.pam_end.argtypes = [C.c_void_p, C.c_int]
    assert p.pam_start(b'other', b'keke', C.byref(conv), C.byref(h)) == 0
    try:
        for name in ('pam_sm_authenticate', 'pam_sm_setcred'):
            f = getattr(m, name)
            f.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_void_p]
            f.restype = C.c_int
            assert f(h, 0, 0, None) == 25  # Native PAM_IGNORE, never success.
    finally:
        assert p.pam_end(h, 0) == 0
    assert not prompts, 'Observer must not ask for input'
    print('Observer native-handle check: both entry points return PAM_IGNORE; no auth/input.')
    PY
  ''
