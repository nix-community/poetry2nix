{ inputs, self }:

let
  inherit (inputs) nixpkgs nix-github-actions treefmt-nix;

  systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
  treefmtEval = f: nixpkgs.lib.genAttrs systems (system: f (
    treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./dev/treefmt.nix
  ));

  mkPkgs =
    system:
    import nixpkgs {
      config = {
        allowAliases = false;
        allowInsecurePredicate = _: true;
      };
      overlays = [ self.overlays.default ];
      inherit system;
    };
in
nix-github-actions.lib.mkGithubMatrix {
  platforms = {
    "x86_64-linux" = "ubuntu-22.04";
    "x86_64-darwin" = "macos-13";
    "aarch64-darwin" = "macos-14";
  };
  checks = {
    x86_64-linux =
      let
        pkgs = mkPkgs "x86_64-linux";
      in
      import ./tests { inherit pkgs; }
      // {
        formatting = treefmtEval.x86_64-linux.config.build.check self;
      };

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
            env.TEST_INPUTS = lib.concatStringsSep " " (
              lib.attrValues (lib.filterAttrs (_: v: lib.isDerivation v) tests)
            );
          } "touch $out";
      };
    aarch64-darwin =
      let
        pkgs = mkPkgs "aarch64-darwin";
        inherit (pkgs) lib;
        tests = import ./tests { inherit pkgs; };
      in
      {
        # Aggregate all tests into one derivation so that only one GHA runner is scheduled for all darwin jobs
        aggregate = pkgs.runCommand "darwin-aggregate"
          {
            env.TEST_INPUTS = lib.concatStringsSep " " (
              lib.attrValues (lib.filterAttrs (_: v: lib.isDerivation v) tests)
            );
          } "touch $out";
      };
  };
}

