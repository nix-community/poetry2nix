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
        poetry2nix = import ./default.nix { inherit pkgs; };
        poetry = pkgs.callPackage ./pkgs/poetry { python = pkgs.python3; inherit poetry2nix; };
      in
      rec {
        packages = {
          inherit poetry;
          poetry2nix = poetry2nix.cli;
          default = poetry2nix.cli;
        };

        legacyPackages = poetry2nix;

        apps = {
          poetry = flake-utils.lib.mkApp { drv = packages.poetry; };
          poetry2nix = flake-utils.lib.mkApp { drv = packages.poetry2nix; };
          default = apps.poetry2nix;
        };
      }));
}
