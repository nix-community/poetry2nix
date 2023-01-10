{
  description = "Poetry2nix flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, flake-utils }:
    rec {
      overlay = import ./overlay.nix;

      templates = {
        app = {
          path = ./templates/app;
          description = "An example of a NixOS container";
        };
      };

      defaultTemplate = templates.app;

    } // (flake-utils.lib.eachDefaultSystem (system:
      rec {
        packages =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            poetry = pkgs.callPackage ./pkgs/poetry { python = pkgs.python3; };
            poetry2nix = import ./default.nix { inherit pkgs poetry; };
          in
          {
            inherit poetry;
            poetry2nix = poetry2nix.cli;
          };

        defaultPackage = packages.poetry2nix;

        apps = {
          poetry = flake-utils.lib.mkApp { drv = packages.poetry; };
          poetry2nix = flake-utils.lib.mkApp { drv = packages.poetry2nix; };
        };

        defaultApp = apps.poetry2nix;
      }));
}
