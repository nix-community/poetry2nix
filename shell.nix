let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {
    overlays = [
      (import ./overlay.nix)
    ];
  };
  tools = pkgs.callPackage ./tools { };
in
pkgs.mkShell {
  buildInputs = [
    tools.flamegraph
    tools.release
    pkgs.nixpkgs-fmt
    pkgs.poetry
    pkgs.niv
  ];
}
