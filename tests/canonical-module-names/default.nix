{ pkgs, lib, poetry2nix, python3 }:

poetry2nix.mkPoetryApplication {
  python = python3;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;

  overrides = [
    poetry2nix.defaultPoetryOverrides
    (import ./poetry-git-overlay.nix { inherit pkgs; })
    (
      _final: prev: {
        pyramid-deferred-sqla = prev.pyramid-deferred-sqla.overridePythonAttrs (
          _old: {
            postPatch = ''
              touch LICENSE
              substituteInPlace setup.py --replace-warn 'setup_requires=["pytest-runner"],' ""
            '';
          }
        );
      }
    )
  ];

}
