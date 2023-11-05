{
  description = "Poetry2nix flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/master";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-github-actions,
    treefmt-nix,
    systems,
  }: let
    eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
    treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./dev/treefmt.nix);
  in
    {
      overlays.default = nixpkgs.lib.composeManyExtensions [(import ./overlay.nix)];
      lib.mkPoetry2Nix = {pkgs}: import ./default.nix {inherit pkgs;};

      githubActions = let
        mkPkgs = system:
          import nixpkgs {
            config = {
              allowAliases = false;
              allowInsecurePredicate = _: true;
            };
            overlays = [self.overlays.default];
            inherit system;
          };
      in
        nix-github-actions.lib.mkGithubMatrix {
          checks = {
            x86_64-linux = let
              pkgs = mkPkgs "x86_64-linux";
            in
              import ./tests {inherit pkgs;}
              // {
                formatting = treefmtEval.x86_64-linux.config.build.check self;
              };

            x86_64-darwin = let
              pkgs = mkPkgs "x86_64-darwin";
              inherit (pkgs) lib;
              tests = import ./tests {inherit pkgs;};
            in {
              # Aggregate all tests into one derivation so that only one GHA runner is scheduled for all darwin jobs
              aggregate =
                pkgs.runCommand "darwin-aggregate"
                {
                  env.TEST_INPUTS = lib.concatStringsSep " " (lib.attrValues (lib.filterAttrs (_: v: lib.isDerivation v) tests));
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
    }
    // (flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowAliases = false;
      };

      poetry2nix = import ./default.nix {inherit pkgs;};
      p2nix-tools = pkgs.callPackage ./tools {inherit poetry2nix;};
    in rec {
      formatter = treefmtEval.${system}.config.build.wrapper;

      packages = {
        poetry2nix = poetry2nix.cli;
        default = poetry2nix.cli;
      };

      devShells = {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            p2nix-tools.env
            p2nix-tools.flamegraph
            nixpkgs-fmt
            poetry
            niv
            jq
            nix-prefetch-git
            nix-eval-jobs
            nix-build-uncached
          ];
        };
      };

      apps = {
        poetry = {
          # https://nixos.wiki/wiki/Flakes
          type = "app";
          program = pkgs.poetry;
        };
        poetry2nix = flake-utils.lib.mkApp {drv = packages.poetry2nix;};
        default = apps.poetry2nix;
      };
    }));
}
