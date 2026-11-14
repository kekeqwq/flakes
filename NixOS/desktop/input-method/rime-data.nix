{ pkgs }:
pkgs.runCommand "rime-ice-ghostty-prefix"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.lua
      pkgs.stdenv.cc
      pkgs.pkg-config
      pkgs.librime
    ];
  }
  ''
    lua ${./tmux-prefix.test.lua} ${./tmux-prefix.lua}
    $CXX -std=c++17 ${./prefix-native.test.cpp} -o prefix-native-test $(pkg-config --cflags --libs rime)
    HOME="$PWD/native-home" ./prefix-native-test ${./tmux-prefix.lua}
    mkdir -p "$out/share"
    cp -rs ${pkgs.rime-ice}/share/rime-data "$out/share/rime-data"
    chmod u+w "$out/share/rime-data" "$out/share/rime-data/lua"
    python3 ${./patch-rime-prefix.py} "$out/share/rime-data"
    cp ${./tmux-prefix.lua} "$out/share/rime-data/lua/ghostty_tmux_prefix.lua"
  ''
