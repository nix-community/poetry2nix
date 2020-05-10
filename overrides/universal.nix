{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
}:

self: super: {

  astroid = super.astroid.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ self.pytest-runner ];
        doCheck = false;
      }
    );

  av = super.av.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.ffmpeg_4 ];
      }
    );

  bcrypt = super.bcrypt.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.libffi ];
      }
    );

  cffi =
    # cffi is bundled with pypy
    if self.python.implementation == "pypy" then null else (
      super.cffi.overridePythonAttrs
        (
          old: {
            buildInputs = old.buildInputs ++ [ pkgs.libffi ];
          }
        )
    );

  cryptography = super.cryptography.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.openssl ];
      }
    );

  django = (
    super.django.overridePythonAttrs
      (
        old: {
          propagatedNativeBuildInputs = (old.propagatedNativeBuildInputs or [ ])
            ++ [ pkgs.gettext ];
        }
      )
  );

  dlib = super.dlib.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ pkgs.dlib.buildInputs;
      }
    );

  h5py = super.h5py.overridePythonAttrs
    (old: {
      buildInputs = old.buildInputs ++ [ pkgs.hdf5 ];
    });

  horovod = super.horovod.overridePythonAttrs
    (
      old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [ pkgs.openmpi ];
      }
    );

  imagecodecs = super.imagecodecs.overridePythonAttrs
    (old: {
      buildInputs = old.buildInputs ++ [
        # Commented out packages are declared required, but not actually
        # needed to build. They are not yet packaged for nixpkgs.
        # bitshuffle
        pkgs.brotli
        # brunsli
        pkgs.bzip2
        pkgs.c-blosc
        # charls
        pkgs.giflib
        pkgs.jxrlib
        pkgs.lcms
        pkgs.libaec
        pkgs.libaec
        pkgs.libjpeg_turbo
        # liblzf
        # liblzma
        pkgs.libpng
        pkgs.libtiff
        pkgs.libwebp
        pkgs.lz4
        pkgs.openjpeg
        pkgs.snappy
        # zfp
        pkgs.zopfli
        pkgs.zstd
        pkgs.zlib
      ];
    });

  # importlib-metadata has an incomplete dependency specification
  importlib-metadata = super.importlib-metadata.overridePythonAttrs
    (
      old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ lib.optional self.python.isPy2 self.pathlib2;
      }
    );

  jupyter = super.jupyter.overridePythonAttrs
    (
      old: {
        # jupyter is a meta-package. Everything relevant comes from the
        # dependencies. It does however have a jupyter.py file that conflicts
        # with jupyter-core so this meta solves this conflict.
        meta.priority = 100;
      }
    );

  lap = super.lap.overridePythonAttrs
    (
      old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [
          self.numpy
        ];
      }
    );

  llvmlite = super.llvmlite.overridePythonAttrs
    (
      old: {
        __impureHostDeps = pkgs.stdenv.lib.optionals pkgs.stdenv.isDarwin [ "/usr/lib/libm.dylib" ];
        passthru = (old.passthru or { }) // { llvm = pkgs.llvm; };
      }
    );

  lockfile = super.lockfile.overridePythonAttrs
    (
      old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [ self.pbr ];
      }
    );

  lxml = super.lxml.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.libxml2 pkgs.libxslt ];
      }
    );

  matplotlib = super.matplotlib.overridePythonAttrs
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
        buildInputs = old.buildInputs
          ++ lib.optional enableGhostscript pkgs.ghostscript
          ++ lib.optional stdenv.isDarwin [ Cocoa ];

        propagatedBuildInputs = old.propagatedBuildInputs ++ [
          pkgs.libpng
          pkgs.freetype
        ]
          ++ stdenv.lib.optionals enableGtk3 [ pkgs.cairo self.pycairo pkgs.gtk3 pkgs.gobject-introspection self.pygobject3 ]
          ++ stdenv.lib.optionals enableTk [ pkgs.tcl pkgs.tk self.tkinter pkgs.libX11 ]
          ++ stdenv.lib.optionals enableQt [ self.pyqt5 ]
        ;
      }
    );

  netcdf4 = super.netcdf4.overridePythonAttrs
    (
      old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [
          pkgs.zlib
          pkgs.netcdf
          pkgs.hdf5
          pkgs.curl
          pkgs.libjpeg
        ];
      }
    );

  openexr = super.openexr.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.openexr pkgs.ilmbase ];
      }
    );

  panel = super.panel.overridePythonAttrs
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.nodejs ];
      }
    );

  peewee = super.peewee.overridePythonAttrs
    (
      old:
      let
        withPostgres = old.passthru.withPostgres or false;
        withMysql = old.passthru.withMysql or false;
      in
      {
        buildInputs = old.buildInputs ++ [ self.cython pkgs.sqlite ];
        propagatedBuildInputs = old.propagatedBuildInputs
          ++ lib.optional withPostgres self.psycopg2
          ++ lib.optional withMysql self.mysql-connector;
      }
    );

  pillow = super.pillow.overridePythonAttrs
    (
      old: {
        buildInputs = with pkgs; [ freetype libjpeg zlib libtiff libwebp tcl lcms2 ] ++ old.buildInputs;
      }
    );

  psycopg2 = super.psycopg2.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.postgresql ];
      }
    );

  psycopg2-binary = super.psycopg2-binary.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.postgresql ];
      }
    );

  pyarrow = super.pyarrow.overridePythonAttrs
    (old: {
      buildInputs = old.buildInputs ++ [
        pkgs.arrow-cpp
      ];
    });

  pycairo =
    super.pycairo.overridePythonAttrs
      (
        old: {

          propagatedBuildInputs = old.propagatedBuildInputs ++ [
            pkgs.cairo
            pkgs.xlibsWrapper
          ];

        }
      );

  pygobject = super.pygobject.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.glib pkgs.gobject-introspection ];
      }
    );

  pycocotools = super.pycocotools.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [
          self.numpy
        ];
      }
    );

  pyopenssl = super.pyopenssl.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.openssl ];
      }
    );

  pytest-runner = super.pytest-runner or super.pytestrunner;

  python-prctl = super.python-prctl.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [
          pkgs.libcap
        ];
      }
    );

  pyzmq = super.pyzmq.overridePythonAttrs
    (
      old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
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
    super.pyqt5.overridePythonAttrs
      (
        old: {
          buildInputs = old.buildInputs ++ [
            pkgs.dbus
            pkgs.qt5.qtbase
            pkgs.qt5.qtsvg
            pkgs.qt5.qtdeclarative
            self.sip
          ]
            ++ lib.optional withConnectivity pkgs.qt5.qtconnectivity
            ++ lib.optional withWebKit pkgs.qt5.qtwebkit
            ++ lib.optional withWebSockets pkgs.qt5.qtwebsockets
          ;
        }
      );

  scipy = super.scipy.overridePythonAttrs
    (
      old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [ self.pybind11 ];
      }
    );

  scikit-learn = super.scikit-learn.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [
          pkgs.gfortran
          pkgs.glibcLocales
        ] ++ lib.optionals stdenv.cc.isClang [
          pkgs.llvmPackages.openmp
        ];
      }
    );

  shapely = super.shapely.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ [ pkgs.geos ];
      }
    );

  tables = super.tables.overridePythonAttrs
    (
      old: {
        HDF5_DIR = "${pkgs.hdf5}";
        propagatedBuildInputs = old.nativeBuildInputs ++ [ pkgs.hdf5 self.numpy self.numexpr ];
      }
    );

  urwidtrees = super.urwidtrees.overridePythonAttrs
    (
      old: {
        propagatedBuildInputs = old.propagatedBuildInputs ++ [
          self.urwid
        ];
      }
    );

  uvloop = super.uvloop.overridePythonAttrs
    (
      old: {
        buildInputs = old.buildInputs ++ lib.optionals stdenv.isDarwin [
          pkgs.darwin.apple_sdk.frameworks.ApplicationServices
          pkgs.darwin.apple_sdk.frameworks.CoreServices
        ];
      }
    );

  # Stop infinite recursion by using bootstrapped pkg from nixpkgs
  wheel = (
    pkgs.python3.pkgs.override {
      python = self.python;
    }
  ).wheel.overridePythonAttrs
    (
      old:
      if old.format == "other" then old else {
        inherit (super.wheel) pname name version src;
      }
    );

  zipp = super.zipp.overridePythonAttrs
    (old: {
      propagatedBuildInputs = old.propagatedBuildInputs ++ [
        self.toml
      ];
    });

}
