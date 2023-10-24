final: prev: {
  poetry2nix = import ./default.nix { pkgs = final; };
}
