self: super: {

  poetry2nix = import ./default.nix { pkgs = self; poetry = self.poetry; };

  poetry = super.callPackage ./pkgs/poetry { python = self.python3; };

}
