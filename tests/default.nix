let
  flake = builtins.getFlake "${toString ../.}";
in
{ pkgs ? import flake.inputs.nixpkgs {
    config = {
      allowAliases = false;
      allowInsecurePredicate = _: true;
    };
    overlays = [ flake.overlays.default ];
  }
}:
let
  poetry2nix = import ./.. { inherit pkgs; };
  callTest = test: attrs: pkgs.callPackage test ({ inherit poetry2nix; } // attrs);

  inherit (pkgs) lib stdenv;

in
{
  trivial = callTest ./trivial { };

  # Uses the updated 1.2.0 lockfile format
  trivial-poetry-1_2_0 = callTest ./trivial-poetry-1_2_0 { };

  legacy = callTest ./legacy { };
  composable-defaults = callTest ./composable-defaults { };
  override = callTest ./override-support { };
  override-default = callTest ./override-default-support { };
  common-pkgs-1 = callTest ./common-pkgs-1 { };
  common-pkgs-2 = callTest ./common-pkgs-2 { };

  env = callTest ./env { };
  pytest-metadata = callTest ./pytest-metadata { };
  pytest-randomly = callTest ./pytest-randomly { };
  file-src-deps = callTest ./file-src-deps { };
  file-src-deps-level2 = callTest ./file-src-deps-level2 { };
  file-wheel-deps = callTest ./file-wheel-deps { };
  file-wheel-deps-level2 = callTest ./file-wheel-deps-level2 { };
  git-deps = callTest ./git-deps { };
  git-deps-1_2_0 = callTest ./git-deps-1_2_0 { };
  git-deps-pinned = callTest ./git-deps-pinned { };
  in-list = callTest ./in-list { };
  path-deps = callTest ./path-deps { };
  path-deps-develop = callTest ./path-deps-develop { };
  path-deps-level2 = callTest ./path-deps-level2 { };
  operators = callTest ./operators { };
  preferWheel = callTest ./prefer-wheel { };
  prefer-wheels = callTest ./prefer-wheels { };
  closure-size = callTest ./closure-size {
    inherit (pkgs) postgresql;
  };
  extras = callTest ./extras { };
  source-filter = callTest ./source-filter { };
  canonical-module-names = callTest ./canonical-module-names { };
  wandb = callTest ./wandb { };
  utf8-pyproject = callTest ./utf8-pyproject { };

  inherit (poetry2nix) cli;

  ansible-molecule = callTest ./ansible-molecule { };
  black = callTest ./black { };
  blinker-1_6_2 = callTest ./blinker-1_6_2 { };
  blinker = callTest ./blinker { };
  bcrypt = callTest ./bcrypt { };
  mk-poetry-packages = callTest ./mk-poetry-packages { };
  mailchimp3 = callTest ./mailchimp3 { };
  markupsafe2 = callTest ./markupsafe2 { };
  mysqlclient = callTest ./mysqlclient { };
  jq = callTest ./jq { };
  ubersmith = callTest ./ubersmith { };
  use-url-wheel = callTest ./use-url-wheel { };
  returns = callTest ./returns { };
  option = callTest ./option { };
  fastapi-utils = callTest ./fastapi-utils { };
  awscli = callTest ./awscli { };
  aiopath = callTest ./aiopath { };
  fetched-projectdir = callTest ./fetched-projectdir { };
  assorted-pkgs = callTest ./assorted-pkgs { };
  watchfiles = callTest ./watchfiles { };
  sqlalchemy = callTest ./sqlalchemy { };
  sqlalchemy2 = callTest ./sqlalchemy2 { };
  tzlocal = callTest ./tzlocal { };

  ml-stack = callTest ./ml-stack { };

  dependency-groups = callTest ./dependency-groups { };

  # And also test with pypy
  # poetry-pypy = poetry.override { python = pkgs.pypy; };
  # poetry-pypy3 = poetry.override { python = pkgs.pypy3; };

  jupyterlab-3 = callTest ./jupyterlab-3 { };
  jupyterlab = callTest ./jupyterlab { };

  # manylinux requires nixpkgs with https://github.com/NixOS/nixpkgs/pull/75763
  # Once this is available in 19.09 and unstable we can re-enable the manylinux test
  manylinux = callTest ./manylinux { };
  shapely = callTest ./shapely { };
  shapely-pre-2 = callTest ./shapely-pre-2 { };
  setuptools = callTest ./setuptools { };

  affine = callTest ./affine { };
  affine-pre-2-4 = callTest ./affine-pre-2-4 { };
  cattrs = callTest ./cattrs { };
  cattrs-pre-23-2 = callTest ./cattrs-pre-23-2 { };
  cdk-nag = callTest ./cdk-nag { };
  arrow = callTest ./arrow { };
  gdal = callTest ./gdal { };
  gitlint-core = callTest ./gitlint-core { };
  gitlint = callTest ./gitlint { };
  jupyter-ydoc = callTest ./jupyter-ydoc { };
  mutmut = callTest ./mutmut { };
  procrastinate = callTest ./procrastinate { };
  pytest-redis = callTest ./pytest-redis { };
  pylint-django = callTest ./pylint-django { };
  pylint-django-pre-2-5-4 = callTest ./pylint-django-pre-2-5-4 { };
  rasterio = callTest ./rasterio { };
  scientific = callTest ./scientific { };
  scipy1_9 = callTest ./scipy1_9 { };
  scipy1_11 = callTest ./scipy1_11 { };
  test-group = callTest ./test-group { };
  nbconvert-wheel = callTest ./nbconvert-wheel { };
  duckdb-wheel = callTest ./duckdb-wheel { };
  shandy-sqlfmt = callTest ./shandy-sqlfmt { };
  textual-dev = callTest ./textual-dev { };
  textual-textarea = callTest ./textual-textarea { };
  fiona-source = callTest ./fiona-source { };
  shapely-wheel = callTest ./shapely-wheel { };
  cffi-pandas-wheel = callTest ./cffi-pandas-wheel { };
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
  markdown-it-py-wheel = callTest ./markdown-it-py-wheel { };
  cairocffi-wheel = callTest ./cairocffi-wheel { };
  cairocffi-no-wheel = callTest ./cairocffi-no-wheel { };
  rpds-py-wheel = callTest ./rpds-py-wheel { };
  rpds-py-no-wheel = callTest ./rpds-py-no-wheel { };
  contourpy-wheel = callTest ./contourpy-wheel { };
  contourpy-no-wheel = callTest ./contourpy-no-wheel { };
  pytesseract = callTest ./pytesseract { };
  sphinx5 = callTest ./sphinx5 { };
  subdirectory = callTest ./subdirectory { };
  plyvel = callTest ./plyvel { };
  awsume = callTest ./awsume { };
  gobject-introspection = callTest ./gobject-introspection { };
  python-versions-or = callTest ./python-versions-or { };
  python-markers = callTest ./python-markers { };
  orjson-test = callTest ./orjson-test { };
  ruff = callTest ./ruff { };
  colour = callTest ./colour { };
  pyodbc-wheel = callTest ./pyodbc-wheel { };
  gnureadline = callTest ./gnureadline { };
} // lib.optionalAttrs (!stdenv.isDarwin) {
  # pyqt5 = (callTest ./pyqt5 { });
  pyqt6 = callTest ./pyqt6 { };
  pyside6 = callTest ./pyside6 { };
  pyarrow-wheel = callTest ./pyarrow-wheel { };
  fiona-wheel = callTest ./fiona-wheel { };

  # Test deadlocks on darwin, sandboxing issue?
  dependency-environment = callTest ./dependency-environment { };

  # Editable tests fails on Darwin because of sandbox paths
  pep600 = callTest ./pep600 { };
  editable = callTest ./editable { };
  editable-egg = callTest ./editable-egg { };
  pendulum = callTest ./pendulum { };

  # Fails because of missing inputs on darwin
  text-generation-webui = callTest ./text-generation-webui { };

  # Cross tests fail on darwin for some strange reason:
  # ERROR: MarkupSafe-2.0.1-cp39-cp39-linux_aarch64.whl is not a supported wheel on this platform.
  extended-cross = callTest ./extended-cross { };
  trivial-cross = callTest ./trivial-cross { };
}
