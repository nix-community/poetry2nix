{ poetry2nix, python3 }:
let
  p2nix = poetry2nix.overrideScope (_self: super: {

    defaultPoetryOverrides = super.defaultPoetryOverrides.extend (_pyself: _pysuper: {
      my-custom-pkg = super.my-custom-pkg.overridePythonAttrs (_oldAttrs: { });
    });

  });

in
p2nix.mkPoetryApplication {
  python = python3;
  projectDir = ./.;
  overrides = p2nix.overrides.withDefaults (_self: super: {
    inherit (super) customjox;
  });
}
