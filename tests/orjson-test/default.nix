{ pkgs
, lib
, poetry2nix
, python310
,
}:
let
  versions = builtins.fromJSON (builtins.readFile ./versions.json);
  # These versions fails because each builds using `maturin >= 0.12.18; < 0.14`,
  # while nixpkgs's rustPlatform uses `maturin > 0.14`. This information is
  # sourced from upstream's `pyproject.toml` `requires = ["maturin>=0.13,<0.15"]`
  #
  # The expected behavior if you build on non-excluded would be `maturin` complaining
  # that `pyproject.toml` does not contain `project.{name,repository,requires-python,classifier}`
  # and `Cargo.toml` does (as they seem to deprecate the old way)
  #
  # Some ways to work around this is:
  # 1. pin to previous nixpkgs (up to user)
  # 2. somehow override maturin build hook to use older version of maturin
  # 3. we maintain patches against pyproject.toml and cargo.toml to make the
  # source works, based on read version.
  exclude-broken-maturin = builtins.filter
    ({ version
     , ...
     }:
      lib.versionAtLeast version "3.8.2")
    versions;
in
pkgs.linkFarm "orjson-test" (builtins.map
  ({ dep
   , version
   , ...
   }: {
    name = "orjson-test-${dep}-${version}}";
    path =
      let
        env = poetry2nix.mkPoetryEnv {
          python = python310;
          pyproject = ./pyproject.toml;
          poetrylock = ./. + "/poetry_${dep}_${version}.lock";
          # src = lib.cleanSource ./.;
          preferWheels = false;
        };
      in
      pkgs.runCommand "orjson-test" { } ''
        ${env}/bin/python -c 'import orjson; print(orjson.dumps(dict(hello="world", foo=14, life=42.0)).decode("utf-8"))'
        touch $out
      '';
  })
  exclude-broken-maturin)
