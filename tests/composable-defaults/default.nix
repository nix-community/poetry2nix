{ poetry2nix, python3 }:
let
  p2nix = poetry2nix.overrideScope' (_: super: {

    defaultPoetryOverrides = super.defaultPoetryOverrides.extend (pyself: pysuper: {
      my-custom-pkg = super.my-custom-pkg.overridePythonAttrs (oldAttrs: { });
    });

  });

in
p2nix.mkPoetryApplication {
  python = python3;
  projectDir = ./.;
  overrides = p2nix.overrides.withDefaults (self: super: {
    inherit (super) customjox;
  });
}
