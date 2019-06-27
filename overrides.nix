{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
}:

let

  addSetupTools = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.setuptools_scm
    ];
  });

  renameUnderscore = self: super: drv: drv.overrideAttrs(old: {
    src = self.fetchPypi {
      pname = builtins.replaceStrings ["-"] ["_"] old.pname;
      version = old.version;
      sha256 = old.src.outputHash;
    };
  });

  renameCapital = let
    capitalise = s: let
      len = builtins.stringLength s;
      first = lib.toUpper (builtins.substring 0 1 s);
    in first + builtins.substring 1 len s;
  in self: super: drv: drv.overrideAttrs(old: {
    src = self.fetchPypi {
      pname = capitalise old.pname;
      version = old.version;
      sha256 = old.src.outputHash;
    };
  });

  # Chain multiple overrides into a single one
  composeOverrides = overrides:
    (self: super: drv: builtins.foldl' (drv: override: override self super drv) drv overrides);

in {

  django-bakery = self: super: drv: drv.overrideAttrs(old: {
    configurePhase = ''
      if ! test -e LICENSE; then
        touch LICENSE
      fi
    '' + old.configurePhase;
  });

  pretalx = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gettext ];
  });

  django = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gettext ];
  });

  django-compressor = renameUnderscore;

  django-csp = renameUnderscore;

  django-context-decorator = renameUnderscore;

  markdown = renameCapital;

  pillow = let
    pillowOverride = self: super: drv: drv.overrideAttrs(old: {
      nativeBuildInputs = [ pkgs.pkgconfig ]
        ++ old.nativeBuildInputs;
      buildInputs = with pkgs; [ freetype libjpeg zlib libtiff libwebp tcl lcms2 ]
        ++ old.buildInputs;
    });
  in composeOverrides [ renameCapital pillowOverride ];

  pytest = addSetupTools;

  six = addSetupTools;

  py = addSetupTools;

  zipp = addSetupTools;

  importlib-metadata = composeOverrides [ renameUnderscore addSetupTools ];

  typing-extensions = renameUnderscore;

  pluggy = addSetupTools;

  jsonschema = addSetupTools;

  python-dateutil = addSetupTools;

  numpy = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gfortran ];
    buildInputs = old.buildInputs ++ [ pkgs.openblasCompat ];
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

}
