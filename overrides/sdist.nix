{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
}:
let

  overridePythonAttrs = drv: fn: drv.overridePythonAttrs (old: if (old.format or "") != "wheel" then (fn old) else { });

in
self: super:

{

  av = overridePythonAttrs super.av
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [
          pkgs.pkgconfig
        ];
      }
    );

  cftime = overridePythonAttrs super.cftime
    (
      old: {
        buildInputs = old.buildInputs ++ [
          self.cython
        ];
      }
    );

  configparser = overridePythonAttrs super.configparser
    (
      old: {
        buildInputs = old.buildInputs ++ [
          self.toml
        ];

        postPatch = ''
          substituteInPlace setup.py --replace 'setuptools.setup()' 'setuptools.setup(version="${old.version}")'
        '';
      }
    );

  django-bakery = overridePythonAttrs super.django-bakery
    (
      old: {
        configurePhase = ''
          if ! test -e LICENSE; then
            touch LICENSE
          fi
        '' + (old.configurePhase or "");
      }
    );

  dlib = overridePythonAttrs super.dlib
    (
      old: {
        # Parallel building enabled
        inherit (pkgs.python.pkgs.dlib) patches;

        enableParallelBuilding = true;
        dontUseCmakeConfigure = true;

        nativeBuildInputs = old.nativeBuildInputs ++ pkgs.dlib.nativeBuildInputs;
      }
    );

  # Environment markers are not always included (depending on how a dep was defined)
  enum34 = if self.pythonAtLeast "3.4" then null else super.enum34;

  faker = overridePythonAttrs super.faker
    (
      old: {
        buildInputs = old.buildInputs ++ [ self.pytest-runner ];
        doCheck = false;
      }
    );

  fancycompleter = overridePythonAttrs super.fancycompleter
    (
      old: {
        postPatch = ''
          substituteInPlace setup.py \
            --replace 'setup_requires="setupmeta"' 'setup_requires=[]' \
            --replace 'versioning="devcommit"' 'version="${old.version}"'
        '';
      }
    );

  fastparquet = overridePythonAttrs super.fastparquet
    (
      old: {
        buildInputs = old.buildInputs ++ [ self.pytest-runner ];
      }
    );

  grandalf = overridePythonAttrs super.grandalf
    (
      old: {
        buildInputs = old.buildInputs ++ [ self.pytest-runner ];
        doCheck = false;
      }
    );

  h5py = overridePythonAttrs super.h5py
    (
      old:
      let
        configure_flags = "--hdf5=${pkgs.hdf5}";
      in
      {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
        buildInputs = old.buildInputs ++ [ self.pkgconfig self.cython ];
        inherit configure_flags;
        postConfigure = ''
          ${self.python.executable} setup.py configure ${configure_flags}
        '';
      }
    );

  imagecodecs = overridePythonAttrs super.imagecodecs
    (
      old: {
        patchPhase = ''
          substituteInPlace setup.py \
            --replace "/usr/include/openjpeg-2.3" \
                      "${pkgs.openjpeg.dev}/include/openjpeg-2.3"
          substituteInPlace setup.py \
            --replace "/usr/include/jxrlib" \
                      "$out/include/libjxr"
          substituteInPlace imagecodecs/_zopfli.c \
            --replace '"zopfli/zopfli.h"' \
                      '<zopfli.h>'
          substituteInPlace imagecodecs/_zopfli.c \
            --replace '"zopfli/zlib_container.h"' \
                      '<zlib_container.h>'
          substituteInPlace imagecodecs/_zopfli.c \
            --replace '"zopfli/gzip_container.h"' \
                      '<gzip_container.h>'
        '';

        preBuild = ''
          mkdir -p $out/include/libjxr
          ln -s ${pkgs.jxrlib}/include/libjxr/**/* $out/include/libjxr
        '';

      }
    );

  isort = overridePythonAttrs super.isort
    (
      old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [ self.setuptools ];
      }
    );

  kiwisolver = overridePythonAttrs super.kiwisolver
    (
      old: {
        buildInputs = old.buildInputs ++ [
          # cppy is at the time of writing not in nixpkgs
          (self.cppy or null)
        ];
      }
    );

  llvmlite = overridePythonAttrs super.llvmlite
    (
      old: {
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
      }
    );

  lxml = overridePythonAttrs super.lxml
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig pkgs.libxml2.dev pkgs.libxslt.dev ];
      }
    );

  markupsafe = overridePythonAttrs super.markupsafe
    (
      old: {
        src = old.src.override { pname = builtins.replaceStrings [ "markupsafe" ] [ "MarkupSafe" ] old.pname; };
      }
    );

  matplotlib = overridePythonAttrs super.matplotlib
    (
      old:
      let
        enableGhostscript = old.passthru.enableGhostscript or false;
        enableGtk3 = old.passthru.enableTk or false;
        enableQt = old.passthru.enableQt or false;
        enableTk = old.passthru.enableTk or false;

        inherit (pkgs.darwin.apple_sdk.frameworks) Cocoa;
      in
      {
        NIX_CFLAGS_COMPILE = stdenv.lib.optionalString stdenv.isDarwin "-I${pkgs.libcxx}/include/c++/v1";

        XDG_RUNTIME_DIR = "/tmp";

        buildInputs = old.buildInputs
          ++ lib.optional enableGhostscript pkgs.ghostscript
          ++ lib.optional stdenv.isDarwin [ Cocoa ];

        nativeBuildInputs = old.nativeBuildInputs ++ [
          pkgs.pkgconfig
        ];

        inherit (super.matplotlib) patches;
      }
    );

  # Calls Cargo at build time for source builds and is really tricky to package
  maturin = super.maturin.override {
    preferWheel = true;
  };

  mccabe = overridePythonAttrs super.mccabe
    (
      old: {
        buildInputs = old.buildInputs ++ [ self.pytest-runner ];
        doCheck = false;
      }
    );

  netcdf4 = overridePythonAttrs super.netcdf4
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [
          self.cython
        ];

        # Variables used to configure the build process
        USE_NCCONFIG = "0";
        HDF5_DIR = lib.getDev pkgs.hdf5;
        NETCDF4_DIR = pkgs.netcdf;
        CURL_DIR = pkgs.curl.dev;
        JPEG_DIR = pkgs.libjpeg.dev;
      }
    );

  numpy = overridePythonAttrs super.numpy
    (
      old:
      let
        blas = old.passthru.args.blas or pkgs.openblasCompat;
        blasImplementation = lib.nameFromURL blas.name "-";
        cfg = pkgs.writeTextFile {
          name = "site.cfg";
          text = (
            lib.generators.toINI { } {
              ${blasImplementation} = {
                include_dirs = "${blas}/include";
                library_dirs = "${blas}/lib";
              } // lib.optionalAttrs (blasImplementation == "mkl") {
                mkl_libs = "mkl_rt";
                lapack_libs = "";
              };
            }
          );
        };
      in
      {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gfortran ];
        buildInputs = old.buildInputs ++ [ blas self.cython ];
        enableParallelBuilding = true;
        preBuild = ''
          ln -s ${cfg} site.cfg
        '';
        passthru = old.passthru // {
          blas = blas;
          inherit blasImplementation cfg;
        };
      }
    );

  openexr = overridePythonAttrs super.openexr
    (
      old: {
        NIX_CFLAGS_COMPILE = [ "-I${pkgs.openexr.dev}/include/OpenEXR" "-I${pkgs.ilmbase.dev}/include/OpenEXR" ];
      }
    );

  pillow = overridePythonAttrs super.pillow
    (
      old: {
        nativeBuildInputs = [ pkgs.pkgconfig ] ++ old.nativeBuildInputs;
      }
    );

  psycopg2 = overridePythonAttrs super.psycopg2
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.postgresql ];
      }
    );

  psycopg2-binary = overridePythonAttrs super.psycopg2-binary
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.postgresql ];
      }
    );

  pyarrow =
    if lib.versionAtLeast super.pyarrow.version "0.16.0" then overridePythonAttrs super.pyarrow
      (
        old:
        let
          parseMinor = drv: lib.concatStringsSep "." (lib.take 2 (lib.splitVersion drv.version));
          _arrow-cpp = pkgs.arrow-cpp.override { inherit (self) python; };
          ARROW_HOME = _arrow-cpp;
          arrowCppVersion = parseMinor pkgs.arrow-cpp;
          pyArrowVersion = parseMinor super.pyarrow;
          errorMessage = "arrow-cpp version (${arrowCppVersion}) mismatches pyarrow version (${pyArrowVersion})";
        in
        if arrowCppVersion != pyArrowVersion then throw errorMessage else {

          nativeBuildInputs = old.nativeBuildInputs ++ [
            self.cython
            pkgs.pkgconfig
            pkgs.cmake
          ];

          preBuild = ''
            export PYARROW_PARALLEL=$NIX_BUILD_CORES
          '';

          PARQUET_HOME = _arrow-cpp;
          inherit ARROW_HOME;

          PYARROW_BUILD_TYPE = "release";
          PYARROW_WITH_PARQUET = true;
          PYARROW_CMAKE_OPTIONS = [
            "-DCMAKE_INSTALL_RPATH=${ARROW_HOME}/lib"

            # This doesn't use setup hook to call cmake so we need to workaround #54606
            # ourselves
            "-DCMAKE_POLICY_DEFAULT_CMP0025=NEW"
          ];

          dontUseCmakeConfigure = true;
        }
      ) else overridePythonAttrs super.pyarrow
      (
        old: {
          nativeBuildInputs = old.nativeBuildInputs ++ [
            self.cython
          ];
        }
      );

  pycairo = overridePythonAttrs super.pycairo
    (
      old: {
        format = "other";

        nativeBuildInputs = old.nativeBuildInputs ++ [
          pkgs.meson
          pkgs.ninja
          pkgs.pkgconfig
        ];

        mesonFlags = [ "-Dpython=${ if self.isPy3k then "python3" else "python"}" ];
      }
    );

  pycocotools = overridePythonAttrs super.pycocotools
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [
          self.cython
        ];
      }
    );

  pygobject = overridePythonAttrs super.pygobject
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
      }
    );

  pylint = overridePythonAttrs super.pylint
    (
      old: {
        buildInputs = old.buildInputs ++ [ self.pytest-runner ];
        doCheck = false;
      }
    );

  pyqt5 =
    let
      drv = super.pyqt5;
      withConnectivity = drv.passthru.args.withConnectivity or false;
      withMultimedia = drv.passthru.args.withMultimedia or false;
      withWebKit = drv.passthru.args.withWebKit or false;
      withWebSockets = drv.passthru.args.withWebSockets or false;
    in
    overridePythonAttrs super.pyqt5
      (
        old: {
          format = "other";

          nativeBuildInputs = old.nativeBuildInputs ++ [
            pkgs.pkgconfig
            pkgs.qt5.qmake
            pkgs.xorg.lndir
            pkgs.qt5.qtbase
            pkgs.qt5.qtsvg
            pkgs.qt5.qtdeclarative
            pkgs.qt5.qtwebchannel
            # self.pyqt5-sip
            self.sip
          ]
            ++ lib.optional withConnectivity pkgs.qt5.qtconnectivity
            ++ lib.optional withMultimedia pkgs.qt5.qtmultimedia
            ++ lib.optional withWebKit pkgs.qt5.qtwebkit
            ++ lib.optional withWebSockets pkgs.qt5.qtwebsockets
          ;

          # Fix dbus mainloop
          patches = pkgs.python3.pkgs.pyqt5.patches or [ ];

          configurePhase = ''
            runHook preConfigure

            export PYTHONPATH=$PYTHONPATH:$out/${self.python.sitePackages}

            mkdir -p $out/${self.python.sitePackages}/dbus/mainloop
            ${self.python.executable} configure.py  -w \
              --confirm-license \
              --no-qml-plugin \
              --bindir=$out/bin \
              --destdir=$out/${self.python.sitePackages} \
              --stubsdir=$out/${self.python.sitePackages}/PyQt5 \
              --sipdir=$out/share/sip/PyQt5 \
              --designer-plugindir=$out/plugins/designer

            runHook postConfigure
          '';

          postInstall = ''
            ln -s ${self.pyqt5-sip}/${self.python.sitePackages}/PyQt5/sip.* $out/${self.python.sitePackages}/PyQt5/
            for i in $out/bin/*; do
              wrapProgram $i --prefix PYTHONPATH : "$PYTHONPATH"
            done

            # Let's make it a namespace package
            cat << EOF > $out/${self.python.sitePackages}/PyQt5/__init__.py
            from pkgutil import extend_path
            __path__ = extend_path(__path__, __name__)
            EOF
          '';

          installCheckPhase =
            let
              modules = [
                "PyQt5"
                "PyQt5.QtCore"
                "PyQt5.QtQml"
                "PyQt5.QtWidgets"
                "PyQt5.QtGui"
              ]
              ++ lib.optional withWebSockets "PyQt5.QtWebSockets"
              ++ lib.optional withWebKit "PyQt5.QtWebKit"
              ++ lib.optional withMultimedia "PyQt5.QtMultimedia"
              ++ lib.optional withConnectivity "PyQt5.QtConnectivity"
              ;
              imports = lib.concatMapStrings (module: "import ${module};") modules;
            in
            ''
              echo "Checking whether modules can be imported..."
              ${self.python.interpreter} -c "${imports}"
            '';

          doCheck = true;

          enableParallelBuilding = true;
        }
      );

  pytest-datadir = overridePythonAttrs super.pytest-datadir
    (
      old: {
        postInstall = ''
          rm -f $out/LICENSE
        '';
      }
    );

  pytest = overridePythonAttrs super.pytest
    (
      old: {
        doCheck = false;
      }
    );

  python-jose = overridePythonAttrs super.python-jose
    (
      old: {
        postPath = ''
          substituteInPlace setup.py --replace "'pytest-runner'," ""
          substituteInPlace setup.py --replace "'pytest-runner'" ""
        '';
      }
    );

  pyzmq = overridePythonAttrs super.pyzmq
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
      }
    );

  rockset = overridePythonAttrs super.rockset
    (
      old: {
        postPatch = ''
          cp ./setup_rockset.py ./setup.py
        '';
      }
    );

  scaleapi = overridePythonAttrs super.scaleapi
    (
      old: {
        postPatch = ''
          substituteInPlace setup.py --replace "install_requires = ['requests>=2.4.2', 'enum34']" "install_requires = ['requests>=2.4.2']" || true
        '';
      }
    );

  pandas = overridePythonAttrs super.pandas
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ self.cython ];
      }
    );

  # Pybind11 is an undeclared dependency of scipy that we need to pick from nixpkgs
  # Make it not fail with infinite recursion
  pybind11 = overridePythonAttrs super.pybind11
    (
      old: {
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          "-DPYBIND11_TEST=off"
        ];
        doCheck = false; # Circular test dependency
      }
    );

  scipy = overridePythonAttrs super.scipy
    (
      old: {
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
      }
    );

  scikit-learn = overridePythonAttrs super.scikit-learn
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [
          self.cython
        ];

        enableParallelBuilding = true;
      }
    );

  shapely = overridePythonAttrs super.shapely
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ self.cython ];
        inherit (pkgs.python3.pkgs.shapely) patches GEOS_LIBRARY_PATH;
      }
    );

  tables = overridePythonAttrs super.tables
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
      }
    );

  tensorpack = overridePythonAttrs super.tensorpack
    (
      old: {
        postPatch = ''
          substituteInPlace setup.cfg --replace "# will call find_packages()" ""
        '';
      }
    );

  vose-alias-method = overridePythonAttrs super.vose-alias-method
    (
      old: {
        postInstall = ''
          rm -f $out/LICENSE
        '';
      }
    );

  zipp =
    if lib.versionAtLeast super.zipp.version "2.0.0" then (
      overridePythonAttrs super.zipp
        (
          old: {
            prePatch = ''
              substituteInPlace setup.py --replace \
              'setuptools.setup()' \
              'setuptools.setup(version="${super.zipp.version}")'
            '';
          }
        )
    ) else super.zipp;

}
