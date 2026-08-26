{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  libusb1,
}:

stdenv.mkDerivation {
  pname = "xrock";
  version = "unstable-2026-08-11";

  src = fetchFromGitHub {
    owner = "xboot";
    repo = "xrock";
    rev = "50effcef229a7e8ff85fde916e635cdd58fe8c09";
    hash = "sha256-doPAs4NIp5JFsFaP5vyqy/Or+cyD8pj3pXmzRYgsARA=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libusb1 ];

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 xrock $out/bin/xrock
    install -Dm644 99-xrock.rules $out/lib/udev/rules.d/99-xrock.rules
    install -Dm644 LICENSE $out/share/licenses/xrock/LICENSE
    runHook postInstall
  '';

  meta = with lib; {
    description = "Low-level tools for Rockchip SoCs (maskrom / loader / flash)";
    homepage = "https://github.com/xboot/xrock";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "xrock";
  };
}
