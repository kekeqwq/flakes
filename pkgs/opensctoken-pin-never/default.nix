# OpenSCToken with PIN-Never patch for YubiKey PIV login.
# Builds OpenSC (CTK backend) + OpenSCToken extension bundle.
# PIN Never + Touch Always keys skip CTK PIN auth and OpenSC internal VERIFY PIN.
{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  openssl,
  zlib,
  libiconv,
  openpace,
  autoreconfHook,
  pkg-config,
}:

let
  # OpenSC with SC_CARDCTL_PIV_YK_PIN_POLICY (not in 0.27.1 release)
  opensc-ctk = stdenv.mkDerivation {
    pname = "opensc-ctk";
    version = "1b2dfc85";
    src = fetchurl {
      url = "https://codeload.github.com/OpenSC/OpenSC/tar.gz/1b2dfc85d24339e8ded2e4224b6ad664b9a97ff3";
      name = "opensc-1b2dfc85.tar.gz";
      hash = "sha256-NfFYCqJEnffVPbRDsD1tgYFGeU7tXytlQepgslHRutk=";
    };
    nativeBuildInputs = [
      autoreconfHook
      pkg-config
    ];
    buildInputs = [
      openssl
      zlib
      libiconv
    ];
    configureFlags = [
      "--disable-shared"
      "--enable-static"
      "--disable-pcsc"
      "--enable-cryptotokenkit"
      "--disable-sm"
      "--disable-readline"
      "--disable-man"
      "--disable-doc"
      "--enable-openssl"
      "--enable-zlib"
    ];
    env.NIX_CFLAGS_COMPILE = "-Wno-error=unused-function";
    enableParallelBuilding = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib $out/src
      cp src/libopensc/.libs/libopensc.a $out/lib/
      # Copy all headers OpenSCToken needs
      cp -R src/libopensc $out/src/
      mkdir -p $out/src/common $out/src/ui $out/src/scconf
      cp src/common/*.h $out/src/common/ 2>/dev/null || true
      cp src/ui/*.h $out/src/ui/ 2>/dev/null || true
      cp src/scconf/*.h $out/src/scconf/ 2>/dev/null || true
      cp config.h $out/src/
      cp config.h $out/  # libopensc/../../config.h resolves here
      # Remove object files to save space
      find $out/src -name '*.o' -delete 2>/dev/null || true
      find $out/src -name '*.lo' -delete 2>/dev/null || true
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = "opensctoken-pin-never";
  version = "1.1.1";

  src = fetchurl {
    url = "https://codeload.github.com/frankmorgner/OpenSCToken/tar.gz/82b359430fe2fe54d49090cdbb94aed1811c047d";
    name = "opensctoken-82b35943.tar.gz";
    hash = "sha256-QQwkJzeObRcNKOggXXRRu5IsZ3GrvL5chj9JmRUEbKM=";
  };

  patches = [ ./pin-never.patch ];

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    openssl
    zlib
    libiconv
    openpace
    opensc-ctk
  ];

  buildPhase = ''
    runHook preBuild
    SDK=$(xcrun --show-sdk-path)
    SRC=OpenSCToken
    OBJ=$TMPDIR/obj
    mkdir -p $OBJ

    CFLAGS="-arch arm64 -isysroot $SDK -mmacosx-version-min=14.0 \
      -fobjc-arc -fmodules \
      -I${opensc-ctk}/src -I${opensc-ctk} \
      -I${openpace}/include -I${openssl.dev}/include \
      -I$SRC -Wno-error=deprecated-declarations"

    for f in Token TokenSession TokenDriver; do
      clang $CFLAGS -c $SRC/$f.m -o $OBJ/$f.o
    done
    clang $CFLAGS -c ${./extension-main.m} -o $OBJ/extension-main.o

    clang -arch arm64 -isysroot $SDK -mmacosx-version-min=14.0 \
      $OBJ/*.o \
      ${opensc-ctk}/lib/libopensc.a \
      -L${lib.getLib openssl}/lib -lcrypto \
      -L${lib.getLib openpace}/lib -leac \
      -L${lib.getLib zlib}/lib -lz \
      -L${libiconv}/lib -liconv \
      -framework Foundation -framework CryptoTokenKit \
      -framework Security -framework AppKit -framework IOKit \
      -o $OBJ/OpenSCToken

    # Build .appex bundle
    APP=$out/OpenSCToken.appex
    mkdir -p $APP/Contents/MacOS $APP/Contents/Frameworks
    cp $OBJ/OpenSCToken $APP/Contents/MacOS/

    # Bundle dynamic libraries
    cp ${lib.getLib openssl}/lib/libcrypto*.dylib $APP/Contents/Frameworks/
    cp ${lib.getLib openpace}/lib/libeac*.dylib $APP/Contents/Frameworks/
    cp ${lib.getLib zlib}/lib/libz*.dylib $APP/Contents/Frameworks/
    cp ${libiconv}/lib/libiconv*.dylib $APP/Contents/Frameworks/ 2>/dev/null || true
    cp ${libiconv}/lib/libcharset*.dylib $APP/Contents/Frameworks/ 2>/dev/null || true

    # Rewrite library paths to bundle-relative
    for lib in $APP/Contents/Frameworks/*.dylib; do
      install_name_tool -id "@loader_path/$(basename $lib)" "$lib"
    done
    for dep in $(otool -L $APP/Contents/MacOS/OpenSCToken | grep '/nix/store/' | awk '{print $1}'); do
      base=$(basename "$dep")
      install_name_tool -change "$dep" "@loader_path/../Frameworks/$base" $APP/Contents/MacOS/OpenSCToken
    done
    for lib in $APP/Contents/Frameworks/*.dylib; do
      for dep in $(otool -L "$lib" | grep '/nix/store/' | awk '{print $1}'); do
        base=$(basename "$dep")
        install_name_tool -change "$dep" "@loader_path/$base" "$lib"
      done
    done

    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall
        APP=$out/OpenSCToken.appex

        # Generate Info.plist
        cat > $APP/Contents/Info.plist << 'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDevelopmentRegion</key><string>en</string>
      <key>CFBundleDisplayName</key><string>OpenSC token driver</string>
      <key>CFBundleExecutable</key><string>OpenSCToken</string>
      <key>CFBundleIdentifier</key><string>com.keke.flakes.opensctoken-app.OpenSCToken</string>
      <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
      <key>CFBundleName</key><string>OpenSCToken</string>
      <key>CFBundlePackageType</key><string>XPC!</string>
      <key>CFBundleShortVersionString</key><string>1.1.1</string>
      <key>CFBundleVersion</key><string>1.1.1</string>
      <key>LSMinimumSystemVersion</key><string>14.0</string>
      <key>NSExtension</key>
      <dict>
        <key>NSExtensionAttributes</key>
        <dict>
          <key>com.apple.ctk.class-id</key>
          <string>com.keke.flakes.opensctoken-app.OpenSCToken</string>
          <key>com.apple.ctk.driver-class</key>
          <string>OpenSCTokenDriver</string>
          <key>com.apple.ctk.token-type</key>
          <string>smartcard</string>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.ctk-tokens</string>
      </dict>
    </dict>
    </plist>
    PLIST

        # Entitlements
        cat > $APP/Contents/entitlements.plist << 'ENT'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>com.apple.security.app-sandbox</key><true/>
      <key>com.apple.security.smartcard</key><true/>
    </dict>
    </plist>
    ENT

        # Sign in Darwin activation (codesign not in Nix sandbox)

        runHook postInstall
  '';

  meta = {
    description = "OpenSCToken with PIN-Never patch for YubiKey PIV macOS login";
    platforms = [ "aarch64-darwin" ];
  };
}
