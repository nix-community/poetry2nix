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
      self: super: {
        pyramid-deferred-sqla = super.pyramid-deferred-sqla.overridePythonAttrs (
          old: {
            postPatch = ''
              touch LICENSE
              substituteInPlace setup.py --replace 'setup_requires=["pytest-runner"],' ""
            '';
          }
        );
      }
    )
  ];

}
