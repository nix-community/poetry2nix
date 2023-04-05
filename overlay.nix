final: prev: {

  poetry2nix = import ./default.nix { pkgs = final; };

  poetry = prev.callPackage ./pkgs/poetry { python = final.python3; inherit (final) poetry2nix; };

}
