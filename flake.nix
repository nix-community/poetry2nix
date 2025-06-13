{
  description = "Poetry2nix flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    # Last working commit from nixos-small-unstable
    nixpkgs.url = "github:NixOS/nixpkgs?rev=75e28c029ef2605f9841e0baa335d70065fe7ae2";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , treefmt-nix
    , ...
    } @ inputs:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
      eachSystem = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./dev/treefmt.nix);
    in
    {
      overlays.default = lib.composeManyExtensions [ (import ./overlay.nix) ];
      lib.mkPoetry2Nix = { pkgs }: import ./default.nix { inherit pkgs; };

      githubActions = import ./actions.nix { inherit inputs self; };

      templates = {
        app = {
          path = ./templates/app;
          description = "An example of a NixOS container";
        };
        default = self.templates.app;
      };
    }
    // (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowAliases = false;
        };

        poetry2nix = import ./default.nix { inherit pkgs; };
        p2nix-tools = pkgs.callPackage ./tools { inherit poetry2nix; };
      in
      {
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

        apps =
          let
            app = flake-utils.lib.mkApp { drv = poetry2nix.cli; };
          in
          {
            poetry = {
              # https://wiki.nixos.org/wiki/Flakes
              type = "app";
              program = "${pkgs.poetry}/bin/poetry";
            };
            poetry2nix = app;
            default = app;
          };
      }
    ));
}
