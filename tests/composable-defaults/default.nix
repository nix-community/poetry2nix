{ poetry2nix, python3 }:
let
  p2nix = poetry2nix.overrideScope (
    _final: prev: {
      defaultPoetryOverrides = prev.defaultPoetryOverrides.extend (
        _pyfinal: _pyprev: {
          my-custom-pkg = prev.my-custom-pkg.overridePythonAttrs (_oldAttrs: { });
        }
      );
    }
  );

in
p2nix.mkPoetryApplication {
  python = python3;
  projectDir = ./.;
  overrides = p2nix.overrides.withDefaults (
    _final: prev: {
      inherit (prev) customjox;
    }
  );
}
