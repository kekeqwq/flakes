{ self, inputs, ... }: {
  flake.overlays.default = import ../pkgs;

  perSystem = { system, ... }: {
    _module.args.pkgs = import self.inputs.nixpkgs {
      inherit system;
      overlays =
        [ self.overlays.default ];
        # [ self.overlays.default (import "${inputs.jovian}/overlay.nix") ];
      config.allowUnfree = true;
    };
  };
}
