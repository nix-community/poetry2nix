let
  pkgs = import (import ./nixpkgs.nix) { };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    curl
    nix-prefetch-github
    jq
  ];
}
