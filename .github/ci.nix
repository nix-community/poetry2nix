let
  sources = import ../nix/sources.nix;

  inherit (import sources.nix-github-actions) mkGithubMatrix;

  mkPkgs = system: import sources.nixpkgs {
    config = {
      allowAliases = false;
      allowInsecurePredicate = x: true;
    };
    overlays = [
      (import ../overlay.nix)
    ];
    inherit system;
  };

in
mkGithubMatrix {
  attrPrefix = "";
  checks = {
    x86_64-linux =
      let
        pkgs = mkPkgs "x86_64-linux";
      in
      import ../tests { inherit pkgs; };

    x86_64-darwin =
      let
        pkgs = mkPkgs "x86_64-darwin";
        inherit (pkgs) lib;


        tests = import ../tests { inherit pkgs; };
      in
      {
        # Aggregate all tests into one derivation so that only one GHA runner is scheduled for all darwin jobs
        aggregate = pkgs.runCommand "darwin-aggregate"
          {
            env.TEST_INPUTS = (lib.concatStringsSep " " (lib.attrValues (lib.filterAttrs (n: v: lib.isDerivation v) tests)));
          } "touch $out";
      };
  };
}
