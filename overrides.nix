{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  stdenv ? pkgs.stdenv,
}:

let

  addSetupTools = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.setuptools_scm
    ];
  });

  # Chain multiple overrides into a single one
  composeOverrides = overrides:
    (self: super: drv: builtins.foldl' (drv: override: override self super drv) drv overrides);

  getAttrDefault = attribute: set: default:
    if builtins.hasAttr attribute set
    then builtins.getAttr attribute set
    else default;

in {

  django-bakery = self: super: drv: drv.overrideAttrs(old: {
    configurePhase = ''
      if ! test -e LICENSE; then
        touch LICENSE
      fi
    '' + (getAttrDefault "configurePhase" old "");
  });

  django = composeOverrides [
    (self: super: drv: drv.overrideAttrs(old: {
      propagatedNativeBuildInputs = (getAttrDefault "propagatedNativeBuildInputs" old [])
      ++ [ pkgs.gettext ];
    }))
  ];

  cffi = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [ pkgs.libffi ];
  });

  cbor2 = addSetupTools;

  configparser = addSetupTools;

  cryptography = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [ pkgs.openssl ];
  });

  markupsafe = self: super: drv: drv.overrideAttrs(old: {
    src = old.src.override { pname = builtins.replaceStrings [ "markupsafe" ] [ "MarkupSafe"] old.pname; };
  });

  hypothesis = addSetupTools;

  pillow = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = [ pkgs.pkgconfig ] ++ old.nativeBuildInputs;
    buildInputs = with pkgs; [ freetype libjpeg zlib libtiff libwebp tcl lcms2 ] ++ old.buildInputs;
  });

  pytest = addSetupTools;

  pytest-mock = addSetupTools;

  six = addSetupTools;

  py = addSetupTools;

  zipp = addSetupTools;

  importlib-metadata = addSetupTools;

  pluggy = addSetupTools;

  jsonschema = addSetupTools;

  python-dateutil = addSetupTools;

  numpy = self: super: drv: drv.overrideAttrs(old: let
    blas = pkgs.openblasCompat;
    blasImplementation = lib.nameFromURL blas.name "-";
    cfg = pkgs.writeTextFile {
      name = "site.cfg";
      text = (lib.generators.toINI {} {
        ${blasImplementation} = {
          include_dirs = "${blas}/include";
          library_dirs = "${blas}/lib";
        } // lib.optionalAttrs (blasImplementation == "mkl") {
          mkl_libs = "mkl_rt";
          lapack_libs = "";
        };
      });
    };
  in {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gfortran ];
    buildInputs = old.buildInputs ++ [ blas ];
    enableParallelBuilding = true;
    preBuild = ''
      ln -s ${cfg} site.cfg
    '';
    passthru = {
      blas = blas;
      inherit blasImplementation cfg;
    };
  });

  psycopg2 = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.postgresql ];
  });

  psycopg2-binary = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.postgresql ];
  });

  lxml = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = with pkgs; old.nativeBuildInputs ++ [ pkgconfig libxml2.dev libxslt.dev ];
    buildInputs = with pkgs; old.buildInputs ++ [ libxml2 libxslt ];
  });

  shapely = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [ pkgs.geos self.cython ];
    inherit (super.shapely) patches GEOS_LIBRARY_PATH;
  });

  lockfile = self: super: drv: drv.overrideAttrs(old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ [ self.pbr ];
  });

  keyring = addSetupTools;

  # Break setuptools infinite recursion because of non-bootstrapped pip
  wheel = self: super: drv: super.wheel.overridePythonAttrs(_: {
    inherit (drv) pname name version src;
  });

  cftime = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.cython
    ];
  });

  inflect = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.setuptools_scm
    ];
  });

  pyarrow = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.cython
    ];
  });

  scipy = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gfortran ];
    setupPyBuildFlags = [ "--fcompiler='gnu95'" ];
    enableParallelBuilding = true;
    buildInputs = old.buildInputs ++ [ self.numpy.blas ];
    preConfigure = ''
      sed -i '0,/from numpy.distutils.core/s//import setuptools;from numpy.distutils.core/' setup.py
      export NPY_NUM_BUILD_JOBS=$NIX_BUILD_CORES
    '';
    preBuild = ''
      ln -s ${self.numpy.cfg} site.cfg
    '';
  });

  matplotlib = self: super: drv: drv.overrideAttrs(old: {
    NIX_CFLAGS_COMPILE = stdenv.lib.optionalString stdenv.isDarwin "-I${pkgs.libcxx}/include/c++/v1";

    XDG_RUNTIME_DIR = "/tmp";

    nativeBuildInputs = old.nativeBuildInputs ++ [
      pkgs.pkgconfig
    ];

    propagatedBuildInputs = old.propagatedBuildInputs ++ [
      pkgs.libpng
      pkgs.freetype
    ];

    inherit (super.matplotlib) patches;
  });

  pycairo = self: super: drv: (drv.overridePythonAttrs(_: {
    format = "other";
  })).overrideAttrs(old: {

    nativeBuildInputs = old.nativeBuildInputs ++ [
      pkgs.meson
      pkgs.ninja
      pkgs.pkgconfig
    ];

    propagatedBuildInputs = old.propagatedBuildInputs ++ [
      pkgs.cairo
      pkgs.xlibsWrapper
    ];

    mesonFlags = [ "-Dpython=${if self.isPy3k then "python3" else "python"}" ];
  });

  llvmlite = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.llvm ];

    # Disable static linking
    # https://github.com/numba/llvmlite/issues/93
    postPatch = ''
      substituteInPlace ffi/Makefile.linux --replace "-static-libstdc++" ""

      substituteInPlace llvmlite/tests/test_binding.py --replace "test_linux" "nope"
    '';

    # Set directory containing llvm-config binary
    preConfigure = ''
      export LLVM_CONFIG=${pkgs.llvm}/bin/llvm-config
    '';

    __impureHostDeps = pkgs.stdenv.lib.optionals pkgs.stdenv.isDarwin [ "/usr/lib/libm.dylib" ];

    passthru.llvm = pkgs.llvm;
  });

  horovod = self: super: drv: drv.overrideAttrs(old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ [ pkgs.openmpi ];
  });

  asciimatics = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.setuptools_scm
    ];
  });

  netcdf4 = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.cython
    ];

    propagatedBuildInputs = old.propagatedBuildInputs ++ [
      pkgs.zlib
      pkgs.netcdf
      pkgs.hdf5
      pkgs.curl
      pkgs.libjpeg
    ];

    # Variables used to configure the build process
    USE_NCCONFIG="0";
    HDF5_DIR = lib.getDev pkgs.hdf5;
    NETCDF4_DIR = pkgs.netcdf;
    CURL_DIR = pkgs.curl.dev;
    JPEG_DIR = pkgs.libjpeg.dev;
  });

  python-prctl = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.setuptools_scm
      pkgs.libcap
    ];
  });

  pygobject = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
    buildInputs = old.buildInputs ++ [ pkgs.glib pkgs.gobject-introspection ];

  });

  av = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [
      pkgs.pkgconfig
    ];
    buildInputs = old.buildInputs ++ [ pkgs.ffmpeg_4 ];
  });

  urwidtrees = self: super: drv: drv.overrideAttrs(old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ [
      self.urwid
    ];
  });

  pycocotools = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.cython
      self.numpy
    ];
  });

  lap = self: super: drv: drv.overrideAttrs(old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ [
      self.numpy
    ];
  });

  grandalf = self: super: drv: drv.overrideAttrs(old: {
    postPatch = ''
      substituteInPlace setup.py --replace "setup_requires=['pytest-runner',]," "setup_requires=[]," || true
    '';
  });

  scaleapi = self: super: drv: drv.overrideAttrs(old: {
    postPatch = ''
      substituteInPlace setup.py --replace "install_requires = ['requests>=2.4.2', 'enum34']" "install_requires = ['requests>=2.4.2']" || true
    '';
  });

  # Environment markers are not always included (depending on how a dep was defined)
  enum34 = self: super: drv: if self.pythonAtLeast "3.4" then null else drv;

  pyopenssl = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [ pkgs.openssl ];
  });

  bcrypt = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [ pkgs.libffi ];
  });

  mccabe = self: super: drv: drv.overrideAttrs(old: {
    postPatch = ''
      substituteInPlace setup.py --replace "setup_requires=['pytest-runner']," "setup_requires=[]," || true
    '';
  });

}
