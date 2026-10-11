{
  description = "Python web scraping course shell. Add libraries to pythonEnv; do not pip install.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/3e40103c8fa6e2d478c7becb75ded2a2176963e7";

  outputs =
    { nixpkgs, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pythonEnv = pkgs.python3.withPackages (
        ps: with ps; [
          requests
          beautifulsoup4
          lxml
          pandas
          pytest
          ipython
        ]
      );
    in
    {
      packages.${system}.default = pythonEnv;
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pythonEnv ];
      };
    };
}
