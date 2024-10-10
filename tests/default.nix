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
  # {x86_64,aarch64}-{linux,darwin}
  trivial = callTest ./trivial { };

  # Uses the updated 1.2.0 lockfile format
  trivial-poetry-1_2_0 = callTest ./trivial-poetry-1_2_0 { };

  legacy = callTest ./legacy { };
  composable-defaults = callTest ./composable-defaults { };
  override = callTest ./override-support { };
  override-default = callTest ./override-default-support { };

  env = callTest ./env { };
  ansible-molecule = callTest ./ansible-molecule { };
  pytest-metadata = callTest ./pytest-metadata { };
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
  prefer-wheels = callTest ./prefer-wheels { };
  closure-size = callTest ./closure-size {
    inherit (pkgs) postgresql;
  };
  extras = callTest ./extras { };
  source-filter = callTest ./source-filter { };
  canonical-module-names = callTest ./canonical-module-names { };
  utf8-pyproject = callTest ./utf8-pyproject { };

  inherit (poetry2nix) cli;

  black = callTest ./black { };
  blinker-1_6_2 = callTest ./blinker-1_6_2 { };
  blinker = callTest ./blinker { };
  bcrypt = callTest ./bcrypt { };
  color-operations = callTest ./color-operations { };
  cryptography = callTest ./cryptography { };
  mk-poetry-packages = callTest ./mk-poetry-packages { };
  mailchimp3 = callTest ./mailchimp3 { };
  markupsafe2 = callTest ./markupsafe2 { };
  mysqlclient = callTest ./mysqlclient { };
  jq = callTest ./jq { };
  ubersmith = callTest ./ubersmith { };
  use-url-src = callTest ./use-url-src { };
  use-url-wheel = callTest ./use-url-wheel { };
  returns = callTest ./returns { };
  option = callTest ./option { };
  fastapi = callTest ./fastapi { };
  fastapi-utils = callTest ./fastapi-utils { };
  awscli = callTest ./awscli { };
  assorted-pkgs = callTest ./assorted-pkgs { };
  watchfiles = callTest ./watchfiles { };
  sqlalchemy = callTest ./sqlalchemy { };
  sqlalchemy2 = callTest ./sqlalchemy2 { };
  tzlocal = callTest ./tzlocal { };
  jake = callTest ./jake { };
  pyproj = callTest ./pyproj { };

  # newer versions of torchvision are built against newer
  # versions of the osx sdk, so for ml-stack, we have an "old"
  # test that ensures we can still build on osx < 10.13 SDK version
  # while:
  #
  # 1. the nix community finishes up work on darwinSDKVersion
  # 2. GitHub figures out its aarch64-darwin story
  ml-stack-old = callTest ./ml-stack-old { };

  dependency-groups = callTest ./dependency-groups { };

  # And also test with pypy
  # poetry-pypy = poetry.override { python = pkgs.pypy; };
  # poetry-pypy3 = poetry.override { python = pkgs.pypy3; };

  jupyterlab-3 = callTest ./jupyterlab-3 { };
  jupyterlab = callTest ./jupyterlab { };

  shapely = callTest ./shapely { };
  shapely-pre-2 = callTest ./shapely-pre-2 { };
  setuptools = callTest ./setuptools { };

  affine = callTest ./affine { };
  affine-pre-2-4 = callTest ./affine-pre-2-4 { };
  cattrs = callTest ./cattrs { };
  cattrs-pre-23-2 = callTest ./cattrs-pre-23-2 { };
  cdk-nag = callTest ./cdk-nag { };
  commitizen = callTest ./commitizen { };
  arrow = callTest ./arrow { };
  gitlint-core = callTest ./gitlint-core { };
  gitlint = callTest ./gitlint { };
  jupyter-ydoc = callTest ./jupyter-ydoc { };
  mutmut = callTest ./mutmut { };
  procrastinate = callTest ./procrastinate { };
  decli = callTest ./decli { };
  decli-pre-0_6_2 = callTest ./decli-pre-0_6_2 { };
  pytest-redis = callTest ./pytest-redis { };
  pylint-django = callTest ./pylint-django { };
  pylint-django-pre-2-5-4 = callTest ./pylint-django-pre-2-5-4 { };
  scipy1_11 = callTest ./scipy1_11 { };
  test-group = callTest ./test-group { };
  nbconvert-wheel = callTest ./nbconvert-wheel { };
  duckdb-wheel = callTest ./duckdb-wheel { };
  shandy-sqlfmt = callTest ./shandy-sqlfmt { };
  fiona-source = callTest ./fiona-source { };
  shapely-wheel = callTest ./shapely-wheel { };
  cffi-pandas-wheel = callTest ./cffi-pandas-wheel { };
  mkdocstrings-wheel = callTest ./mkdocstrings-wheel { };
  test-extras = callTest ./test-extras { };
  test-no-extras = callTest ./test-no-extras { };
  missing-iswheel = callTest ./missing-iswheel { };
  wheel-wheel = callTest ./wheel-wheel { };
  fancycompleter-wheel = callTest ./fancycompleter-wheel { };
  matplotlib-3-7 = callTest ./matplotlib-3-7 { };
  matplotlib-3-9 = callTest ./matplotlib-3-9 { };
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
  subdirectory = callTest ./subdirectory { };
  plyvel = callTest ./plyvel { };
  awsume = callTest ./awsume { };
  gobject-introspection = callTest ./gobject-introspection { };
  pydantic-1 = callTest ./pydantic-1 { };
  python-versions-or = callTest ./python-versions-or { };
  python-markers = callTest ./python-markers { };
  orjson-test = callTest ./orjson-test { };
  ruff = callTest ./ruff { };
  colour = callTest ./colour { };
  gnureadline = callTest ./gnureadline { };
  twisted = callTest ./twisted { };
  scientific = callTest ./scientific { };
  apsw = callTest ./apsw { };
  no-infinite-recur-on-missing-gitignores = callTest ./no-infinite-recur-on-missing-gitignores { };
  pyzmq = callTest ./pyzmq { };
  git-subdirectory-hook = callTest ./git-subdirectory-hook { };
  pandas = callTest ./pandas { };
  python-magic = callTest ./python-magic { };
  avro-python3 = callTest ./avro-python3 { };
  mpi4py-test = callTest ./mpi4py-test { };
  ckzg = callTest ./ckzg { };
  thrift = callTest ./thrift { };
  scikit-learn = callTest ./scikit-learn { };
  soundfile-wheel = callTest ./soundfile-wheel { };
  soundfile = callTest ./soundfile { };
  pyogrio = callTest ./pyogrio { };
  dask-dataframe = callTest ./dask-dataframe { };
  argon2-cffi-bindings-python-3-12 = callTest ./argon2-cffi-bindings-python-3-12 { };
} // lib.optionalAttrs (!stdenv.isDarwin) {
  # Editable tests fails on Darwin because of sandbox paths
  pep600 = callTest ./pep600 { };
  editable = callTest ./editable { };

  # Fails because of missing inputs on darwin
  text-generation-webui = callTest ./text-generation-webui { };

  # Cross tests fail on darwin for some strange reason:
  # ERROR: MarkupSafe-2.0.1-cp39-cp39-linux_aarch64.whl is not a supported wheel on this platform.
  extended-cross = callTest ./extended-cross { };
  trivial-cross = callTest ./trivial-cross { };

  # impure when using a wheel
  pyodbc-wheel = callTest ./pyodbc-wheel { };
  # linux-only API (AIO)
  aiopath = callTest ./aiopath { };
  # doesn't compile on darwin
  matplotlib-3-6 = callTest ./matplotlib-3-6 { };
  # the version of scipy used here doesn't build from source on darwin
  scipy1_9 = callTest ./scipy1_9 { };
} // lib.optionalAttrs (!stdenv.isAarch64) {
  # no wheel for aarch64 for the tested packages
  # x86_64-{linux,darwin}
  preferWheel = callTest ./prefer-wheel { };
} // lib.optionalAttrs (!stdenv.isDarwin || stdenv.isAarch64) {
  # {x86_64,aarch64}-linux
  # aarch64-darwin
  pyarrow-wheel = callTest ./pyarrow-wheel { };
  fiona-wheel = callTest ./fiona-wheel { };
  ml-stack = callTest ./ml-stack { };
  flink = callTest ./flink { };
} // lib.optionalAttrs (stdenv.isLinux && stdenv.isx86_64) {
  # x86_64-linux
  pyqt6 = callTest ./pyqt6 { };
  vllm-wheel = callTest ./vllm-wheel { };
} // lib.optionalAttrs (!(stdenv.isLinux && stdenv.isAarch64)) {
  # x86_64-linux
  # {x86_64,aarch64}-darwin
  pyside6 = callTest ./pyside6 { };
  textual-dev = callTest ./textual-dev { };
  textual-textarea = callTest ./textual-textarea { };
  sphinx5 = callTest ./sphinx5 { };
  wandb = callTest ./wandb { };
  # sphinx build from the following tests fail on aarch64-linux
  manylinux = callTest ./manylinux { };
  gdal = callTest ./gdal { };
  rasterio = callTest ./rasterio { };
  common-pkgs-1 = callTest ./common-pkgs-1 { };
  common-pkgs-2 = callTest ./common-pkgs-2 { };
  pytest-randomly = callTest ./pytest-randomly { };
  fetched-projectdir = callTest ./fetched-projectdir { };
  cmdstanpy = callTest ./cmdstanpy { };
} // lib.optionalAttrs (stdenv.isLinux && stdenv.isx86_64) {
  # x86_86-linux
  pendulum = callTest ./pendulum { };
  pendulum-with-rust = callTest ./pendulum-with-rust { };
  tensorflow = callTest ./tensorflow { };
  # Test deadlocks on darwin and fails to start at all with aarch64-linux,
  # sandboxing issue?
  dependency-environment = callTest ./dependency-environment { };
  editable-egg = callTest ./editable-egg { };
}
