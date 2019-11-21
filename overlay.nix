self: super: {

  poetry2nix = import ./default.nix { pkgs = self; poetry = self.poetry; };

  poetry = let
    # Ensure we're manylinux compatible.
    # https://github.com/NixOS/nixpkgs/issues/71935
    python = (super.python3.overrideAttrs(oldAttrs: {
      postFixup = ''
        rm $out/lib/${python.libPrefix}/_manylinux.py
      '';
    })).override {
      self = python;
    };
  in super.callPackage ./pkgs/poetry { inherit python; };

}
