{
  poetry2nix,
  python3,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
  py = env.python;
  pkg = py.pkgs.nbconvert;
  isNbConvertWheel = pkg.src.isWheel;
in
assert isNbConvertWheel;
runCommand "nbconvert-wheel" { } ''
  ${env}/bin/python -c 'import nbconvert as nbc; print(nbc.__version__)' > $out
  grep -q '"${pkg}", "share", "jupyter"' "${pkg}/${py.sitePackages}/nbconvert/exporters/templateexporter.py"
''
