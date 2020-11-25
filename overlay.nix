final: prev: {

  poetry2nix = import ./default.nix { pkgs = final; poetry = final.poetry; };

  poetry = prev.callPackage ./pkgs/poetry { python = final.python3; };

}
