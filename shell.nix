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
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {
    overlays = [
      (import ./overlay.nix)
      (self: super: {
        p2nix-tools = self.callPackage ./tools { };
      })
    ];
  };

in
pkgs.mkShell {
  NIX_PATH = "nixpkgs=${sources.nixpkgs}";
  packages = packages pkgs;
}
