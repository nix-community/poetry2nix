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

  pillow = let
    pillowOverride = self: super: drv: drv.overrideAttrs(old: {
      nativeBuildInputs = [ pkgs.pkgconfig ]
        ++ old.nativeBuildInputs;
      buildInputs = with pkgs; [ freetype libjpeg zlib libtiff libwebp tcl lcms2 ]
        ++ old.buildInputs;
    });
  in pillowOverride;

  pytest = addSetupTools;

  pytest-mock = addSetupTools;

  six = addSetupTools;

  py = addSetupTools;

  zipp = addSetupTools;

  importlib-metadata = addSetupTools;

  pluggy = addSetupTools;

  jsonschema = addSetupTools;

  python-dateutil = addSetupTools;

  numpy = self: super: drv: drv.overrideAttrs(old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gfortran ];
    buildInputs = old.buildInputs ++ [ pkgs.openblasCompat ];
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

}
