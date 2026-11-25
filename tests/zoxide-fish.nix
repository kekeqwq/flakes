{ pkgs }:
pkgs.runCommand "zoxide-fish-check"
  {
    nativeBuildInputs = [
      pkgs.fish
      pkgs.zoxide
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    export XDG_DATA_HOME="$TMPDIR/data"
    export _ZO_DATA_DIR="$TMPDIR/zoxide"
    mkdir -p "$HOME"
    cat > "$TMPDIR/check.fish" <<'FISH'
    # Same loader text as Home Manager's zoxide fish integration.
    zoxide init fish | source
    functions --query z; or begin; echo "z missing"; exit 1; end
    functions --query zi; or begin; echo "zi missing"; exit 1; end
    # zoxide must never alias cd to z: that loop is what its init guards against.
    not alias | string match -qr '^alias cd=z'; or begin; echo "cd aliased to z"; exit 1; end
    set -l root $HOME/work
    mkdir -p $root/alpha $root/beta
    cd $root/alpha
    cd $root/beta
    z alpha
    test "$PWD" = "$root/alpha"; or begin; echo "z alpha -> $PWD"; exit 1; end
    z -
    test "$PWD" = "$root/beta"; or begin; echo "z - -> $PWD"; exit 1; end
    z -- $root/alpha
    test "$PWD" = "$root/alpha"; or begin; echo "z -- -> $PWD"; exit 1; end
    z
    test "$PWD" = "$HOME"; or begin; echo "z no-arg -> $PWD"; exit 1; end
    FISH
    ${pkgs.fish}/bin/fish "$TMPDIR/check.fish"
    touch "$out"
  ''
