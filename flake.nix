{
  description = "Poetry2nix flake";

  inputs = {
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
    , treefmt-nix
    , ...
    } @ inputs:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];

      forAllSystems = f: lib.genAttrs
        systems
        (system: f nixpkgs.legacyPackages.${system});

      # Taking the mkApp functionality from flake-utils, so we don't need it
      # as a dependency
      mkApp =
        { drv
        , name ? drv.pname or drv.name
        , exePath ? drv.passthru.exePath or "/bin/${name}"
        }:
        {
          type = "app";
          program = "${drv}${exePath}";
        };
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

      formatter = forAllSystems (pkgs:
        let
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./dev/treefmt.nix;
        in
        treefmtEval.config.build.wrapper);

      packages = forAllSystems (pkgs:
        let
          poetry2nix = self.lib.mkPoetry2Nix { inherit pkgs; };
        in
        {
          poetry2nix = poetry2nix.cli;
          default = poetry2nix.cli;
        });

      apps = forAllSystems (pkgs:
        let
          poetry2nix = self.lib.mkPoetry2Nix { inherit pkgs; };

          default = mkApp { drv = poetry2nix.env; };
        in
        {
          inherit default;
          poetry2nix = default;

          poetry = {
            # https://wiki.nixos.org/wiki/Flakes
            type = "app";
            program = "${pkgs.poetry}/bin/poetry";
          };
        });

      devShells = forAllSystems (pkgs:
        let
          poetry2nix = self.lib.mkPoetry2Nix { inherit pkgs; };
          p2nix-tools = pkgs.callPackage ./tools { inherit poetry2nix; };
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [
              p2nix-tools.env
              p2nix-tools.flamegraph

              pkgs.nixpkgs-fmt
              pkgs.poetry
              pkgs.niv
              pkgs.jq
              pkgs.nix-prefetch-git
              pkgs.nix-eval-jobs
              pkgs.nix-build-uncached
            ];
          };
        });
    };
}
