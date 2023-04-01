let
  sources = import ../nix/sources.nix;
in
{ pkgs ? import sources.nixpkgs {
    config = {
      allowAliases = false;
      allowInsecurePredicate = x: true;
    };
    overlays = [
      (import ../overlay.nix)
    ];
  }
}:
let
  poetry = pkgs.callPackage ../pkgs/poetry { python = pkgs.python3; inherit poetry2nix; };
  poetry2nix = import ./.. { inherit pkgs; };
  poetryLib = import ../lib.nix { inherit pkgs; lib = pkgs.lib; stdenv = pkgs.stdenv; };
  pep425 = pkgs.callPackage ../pep425.nix { inherit poetryLib; python = pkgs.python3; };
  pep425PythonOldest = pkgs.callPackage ../pep425.nix { inherit poetryLib; python = pkgs.python38; };
  pep425OSX = pkgs.callPackage ../pep425.nix { inherit poetryLib; isLinux = false; python = pkgs.python3; };
  skipTests = builtins.filter (t: builtins.typeOf t != "list") (builtins.split "," (builtins.getEnv "SKIP_TESTS"));
  callTest = test: attrs: pkgs.callPackage test ({ inherit poetry2nix; } // attrs);

  # HACK: Return null on MacOS since the test in question fails
  skipOSX = drv: if pkgs.stdenv.isDarwin then builtins.trace "Note: Skipping ${drv.name} on OSX" (pkgs.runCommand drv.name { } "touch $out") else drv;

in
builtins.removeAttrs
{
  trivial = callTest ./trivial { };

  # Uses the updated Poetry 1.2.0 format
  trivial-poetry-1_2_0 = callTest ./trivial-poetry-1_2_0 { };

  legacy = callTest ./legacy { };
  composable-defaults = callTest ./composable-defaults { };
  override = callTest ./override-support { };
  override-default = callTest ./override-default-support { };
  common-pkgs-1 = callTest ./common-pkgs-1 { };
  common-pkgs-2 = callTest ./common-pkgs-2 { };
  pep425 = pkgs.callPackage ./pep425 { inherit pep425; inherit pep425OSX; inherit pep425PythonOldest; };
  pep600 = skipOSX (callTest ./pep600 { });
  env = callTest ./env { };
  pytest-randomly = callTest ./pytest-randomly { };
  file-src-deps = callTest ./file-src-deps { };
  file-src-deps-level2 = callTest ./file-src-deps-level2 { };
  file-wheel-deps = callTest ./file-wheel-deps { };
  file-wheel-deps-level2 = callTest ./file-wheel-deps-level2 { };
  git-deps = callTest ./git-deps { };
  git-deps-1_2_0 = callTest ./git-deps-1_2_0 { };
  git-deps-pinned = callTest ./git-deps-pinned { };
  in-list = callTest ./in-list { };
  cli = poetry2nix;
  path-deps = callTest ./path-deps { };
  path-deps-develop = callTest ./path-deps-develop { };
  path-deps-level2 = callTest ./path-deps-level2 { };
  operators = callTest ./operators { };
  preferWheel = callTest ./prefer-wheel { };
  prefer-wheels = callTest ./prefer-wheels { };
  closure-size = callTest ./closure-size {
    inherit poetry;
    inherit (pkgs) postgresql;
  };
  # pyqt5 = skipOSX (callTest ./pyqt5 { });
  extras = callTest ./extras { };
  source-filter = callTest ./source-filter { };
  canonical-module-names = callTest ./canonical-module-names { };
  wandb = callTest ./wandb { };
  utf8-pyproject = callTest ./utf8-pyproject { };

  # Test deadlocks on darwin, sandboxing issue?
  dependency-environment = skipOSX (callTest ./dependency-environment { });

  # Editable tests fails on Darwin because of sandbox paths
  editable = skipOSX (callTest ./editable { });
  editable-egg = skipOSX (callTest ./editable-egg { });

  ansible-molecule = callTest ./ansible-molecule { };
  bcrypt = callTest ./bcrypt { };
  mk-poetry-packages = callTest ./mk-poetry-packages { };
  markupsafe2 = callTest ./markupsafe2 { };
  pendulum = skipOSX (callTest ./pendulum { });
  # uwsgi = callTest ./uwsgi { };  # Commented out because build is flaky (unrelated to poetry2nix)
  jq = callTest ./jq { };
  ubersmith = callTest ./ubersmith { };
  returns = callTest ./returns { };
  option = callTest ./option { };
  fastapi-utils = callTest ./fastapi-utils { };
  awscli = callTest ./awscli { };
  aiopath = callTest ./aiopath { };
  fetched-projectdir = callTest ./fetched-projectdir { };
  assorted-pkgs = callTest ./assorted-pkgs { };
  watchfiles = callTest ./watchfiles { };
  sqlalchemy = callTest ./sqlalchemy { };
  tzlocal = callTest ./tzlocal { };

  # Cross tests fail on darwin for some strange reason:
  # ERROR: MarkupSafe-2.0.1-cp39-cp39-linux_aarch64.whl is not a supported wheel on this platform.
  extended-cross = skipOSX (callTest ./extended-cross { });
  trivial-cross = skipOSX (callTest ./trivial-cross { });

  # Inherit test cases from nixpkgs
  nixops = pkgs.nixops;
  nixops_unstable = skipOSX pkgs.nixops_unstable;

  # Rmfuse fails on darwin because osxfuse only implements fuse api v2
  rmfuse = skipOSX pkgs.rmfuse;

  ml-stack = callTest ./ml-stack { };

  # Test building poetry
  inherit poetry;

  poetry-env =
    let
      env = poetry2nix.mkPoetryEnv {
        projectDir = ../pkgs/poetry;
        groups = [ "typing" ];
      };
    in
    pkgs.runCommand "poetry-env-test" { } ''
      ${env}/bin/python -c 'import requests'
      ${env}/bin/python -c 'import mypy'
      touch $out
    '';

  dependency-groups = callTest ./dependency-groups { };

  # And also test with pypy
  # poetry-pypy = poetry.override { python = pkgs.pypy; };
  # poetry-pypy3 = poetry.override { python = pkgs.pypy3; };

  jupyterlab = callTest ./jupyterlab { };

  # manylinux requires nixpkgs with https://github.com/NixOS/nixpkgs/pull/75763
  # Once this is available in 19.09 and unstable we can re-enable the manylinux test
  manylinux = callTest ./manylinux { };
  shapely = callTest ./shapely { };
  shapely-pre-2 = callTest ./shapely-pre-2 { };
  setuptools = callTest ./setuptools { };

  affine = callTest ./affine { };
  affine-pre-2-4 = callTest ./affine-pre-2-4 { };
  gdal = callTest ./gdal { };
  gitlint-core = callTest ./gitlint-core { };
  gitlint = callTest ./gitlint { };
  jupyter-ydoc = callTest ./jupyter-ydoc { };
  mutmut = callTest ./mutmut { };
  rasterio = callTest ./rasterio { };
  scientific = callTest ./scientific { };
  scipy1_9 = callTest ./scipy1_9 { };
  test-group = callTest ./test-group { };
  nbconvert-wheel = callTest ./nbconvert-wheel { };
  duckdb-wheel = callTest ./duckdb-wheel { };
  fiona-source = callTest ./fiona-source { };
  fiona-wheel = callTest ./fiona-wheel { };
  shapely-wheel = callTest ./shapely-wheel { };
  cffi-pandas-wheel = callTest ./cffi-pandas-wheel { };
  pyarrow-wheel = callTest ./pyarrow-wheel { };
  mkdocstrings-wheel = callTest ./mkdocstrings-wheel { };
  test-extras = callTest ./test-extras { };
  test-no-extras = callTest ./test-no-extras { };
  missing-iswheel = callTest ./missing-iswheel { };
  wheel-wheel = callTest ./wheel-wheel { };
  fancycompleter-wheel = callTest ./fancycompleter-wheel { };
  matplotlib-pre-3-7 = callTest ./matplotlib-pre-3-7 { };
  matplotlib-post-3-7 = callTest ./matplotlib-post-3-7 { };
  rfc3986-validator = callTest ./rfc3986-validator { };
  virtualenv-pre-20-18 = callTest ./virtualenv-pre-20-18 { };
  virtualenv-post-20-18 = callTest ./virtualenv-post-20-18 { };
  grpcio-wheel = callTest ./grpcio-wheel { };
  panel-wheels = callTest ./panel-wheels { };
}
  skipTests
