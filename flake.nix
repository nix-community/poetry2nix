{
  description = "Poetry2nix flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, flake-utils }:
    {
      overlay = import ./overlay.nix;

      templates = {
        app = {
          path = ./templates/app;
          description = "An example of a NixOS container";
        };
        default = self.templates.app;
      };

    } // (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        poetry = pkgs.callPackage ./pkgs/poetry { python = pkgs.python3; };
        poetry2nix = import ./default.nix { inherit pkgs poetry; };
      in
      rec {
        packages = {
          inherit poetry;
          poetry2nix = poetry2nix.cli;
          default = poetry2nix.cli;
        };


        apps = {
          poetry = flake-utils.lib.mkApp { drv = packages.poetry; };
          poetry2nix = flake-utils.lib.mkApp { drv = packages.poetry2nix; };
          default = apps.poetry2nix;
        };
      }));
}
