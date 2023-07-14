{ packages ? pkgs: [
    pkgs.p2nix-tools.env
    pkgs.p2nix-tools.flamegraph
    pkgs.nixpkgs-fmt
    pkgs.poetry
    pkgs.niv
    pkgs.jq
    pkgs.nix-prefetch-git
    pkgs.nix-eval-jobs
    pkgs.nix-build-uncached
  ]
}:

let
  flake = builtins.getFlake "${toString ./.}";

  pkgs = import flake.inputs.nixpkgs {
    overlays = [
      flake.overlay
      (self: super: {
        p2nix-tools = self.callPackage ./tools { };
      })
    ];
  };

in
pkgs.mkShell {
  NIX_PATH = "nixpkgs=${flake.inputs.nixpkgs}";
  packages = packages pkgs;
}
