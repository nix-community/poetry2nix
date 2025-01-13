{ lib, poetry2nix }:
let
  drv = poetry2nix.mkPoetryApplication {
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    src = lib.cleanSource ./.;
    overrides =
      poetry2nix.overrides.withDefaults
        # This is also in overrides.nix but repeated for completeness
        (
          _final: prev: {
            maturin = prev.maturin.override {
              preferWheel = true;
            };
            funcy = prev.funcy.overridePythonAttrs (_old: {
              preferWheel = true;
            });
          }
        );
  };
  isWheelMaturin = drv.passthru.python.pkgs.maturin.src.isWheel or false;
  isWheelFuncy = drv.passthru.python.pkgs.funcy.src.isWheel or false;
in
assert isWheelMaturin;

# HACK https://github.com/nix-community/poetry2nix/pull/948
# TODO Be able some day to invert this assertion
assert !isWheelFuncy;
drv
