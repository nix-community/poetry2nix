{ lib, poetry2nix, python37 }:
let
  drv = poetry2nix.mkPoetryApplication {
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    src = lib.cleanSource ./.;
    overrides = poetry2nix.overrides.withDefaults
      # This is also in overrides.nix but repeated for completeness
      (
        self: super: {
          maturin = super.maturin.override {
            preferWheel = true;
          };
          funcy = super.funcy.overridePythonAttrs (old: {
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
