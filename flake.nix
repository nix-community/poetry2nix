{
  description = "Poetry2nix flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";

  inputs.nix-github-actions.url = "github:nix-community/nix-github-actions";
  inputs.nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, nix-github-actions }:
    {
      overlay = import ./overlay.nix;

      githubActions =
        let
          mkPkgs = system: import nixpkgs {
            config = {
              allowAliases = false;
              allowInsecurePredicate = x: true;
            };
            overlays = [ self.overlay ];
            inherit system;
          };
        in
        nix-github-actions.lib.mkGithubMatrix {
          checks = {
            x86_64-linux =
              let
                pkgs = mkPkgs "x86_64-linux";
              in
              import ./tests { inherit pkgs; };

            x86_64-darwin =
              let
                pkgs = mkPkgs "x86_64-darwin";
                inherit (pkgs) lib;
                tests = import ./tests { inherit pkgs; };
              in
              {
                # Aggregate all tests into one derivation so that only one GHA runner is scheduled for all darwin jobs
                aggregate = pkgs.runCommand "darwin-aggregate"
                  {
                    env.TEST_INPUTS = (lib.concatStringsSep " " (lib.attrValues (lib.filterAttrs (n: v: lib.isDerivation v) tests)));
                  } "touch $out";
              };
          };
        };

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
