{
  swaylock-effects,
  pam,
  lib,
  python3,
}:
swaylock-effects.overrideAttrs (old: {
  pname = "swaylock-effects-security-key";
  patches = (old.patches or [ ]) ++ [ ./parallel-key-auth.patch ];
  postPatch = (old.postPatch or "") + ''
    cp ${./key-auth-client.c} key-auth-client.c
    cp ${./key-auth-client.h} key-auth-client.h
    substituteInPlace key-auth-client.c \
      --replace-fail '@keyAuthHelper@' "$out/libexec/swaylock-key-auth"
  '';
  postBuild = (old.postBuild or "") + ''
    $CC -std=c11 -Wall -Wextra -Werror -O2 \
      -I${lib.getDev pam}/include ${./key-auth-worker.c} \
      -L${lib.getLib pam}/lib -lpam -o swaylock-key-auth
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${python3}/bin/python3 ${./worker.test.py} ${./key-auth-worker.c} ${lib.getDev pam}/include "$CC"
    ${python3}/bin/python3 ${./client.test.py} ${./key-auth-client.c} ${./key-auth-client.h} "$CC"
    ${python3}/bin/python3 ${./loop.test.py} ${old.src}/loop.c ${old.src}/log.c ${old.src}/include "$CC"
    runHook postCheck
  '';
  postInstall = (old.postInstall or "") + ''
    install -Dm755 swaylock-key-auth "$out/libexec/swaylock-key-auth"
  '';
})
