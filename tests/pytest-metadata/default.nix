{ lib, poetry2nix, python3 }:

poetry2nix.mkPoetryApplication {
  python = python3;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
  # Workaround `ModuleNotFoundError: No module named 'poetry'`
  # cf. https://github.com/nix-community/poetry2nix/blob/master/docs/edgecases.md#modulenotfounderror-no-module-named-packagename
  overrides =
    let
      pypkgs-build-requirements = {
        pytest-select = [ "poetry" ];
      };
    in
    poetry2nix.defaultPoetryOverrides.extend (self: super:
      builtins.mapAttrs
        (package: build-requirements:
          (builtins.getAttr package super).overridePythonAttrs (old: {
            buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg: if builtins.isString pkg then builtins.getAttr pkg super else pkg) build-requirements);
          })
        )
        pypkgs-build-requirements
    );
}
