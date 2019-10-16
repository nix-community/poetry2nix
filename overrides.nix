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

  renameLiteral = pname: (self: super: drv: drv.overrideAttrs(old: {
    src = old.src.override { inherit pname; };
  }));

  renameUnderscore = self: super: drv: drv.overrideAttrs(old: {
    src = old.src.override { pname = builtins.replaceStrings ["-"] ["_"] old.pname; };
  });

  renameCapital = let
    capitalise = s: let
      len = builtins.stringLength s;
      first = lib.toUpper (builtins.substring 0 1 s);
    in first + builtins.substring 1 len s;
  in self: super: drv: drv.overrideAttrs(old: {
    src = old.src.override { pname = capitalise old.pname; };
  });

  # Chain multiple overrides into a single one
  composeOverrides = overrides:
    (self: super: drv: builtins.foldl' (drv: override: override self super drv) drv overrides);

  getAttrDefault = attribute: set: default:
    if builtins.hasAttr attribute set
    then builtins.getAttr attribute set
    else default;

in {

  babel = renameCapital;

  django-bakery = self: super: drv: drv.overrideAttrs(old: {
    configurePhase = ''
      if ! test -e LICENSE; then
        touch LICENSE
      fi
    '' + old.configurePhase;
  });

  vat-moss = renameUnderscore;

  django = composeOverrides [
    renameCapital
    (self: super: drv: drv.overrideAttrs(old: {
      propagatedNativeBuildInputs = (getAttrDefault "propagatedNativeBuildInputs" old [])
      ++ [ pkgs.gettext ];
    }))
  ];

  click = renameCapital;

  cffi = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [ pkgs.libffi ];
  });

  configparser = addSetupTools;

  cryptography = self: super: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [ pkgs.openssl ];
  });

  django-compressor = renameUnderscore;

  django-csp = renameUnderscore;

  django-context-decorator = renameUnderscore;

  markdown = renameCapital;

  markupsafe = self: super: drv: drv.overrideAttrs(old: {
    src = old.src.override { pname = builtins.replaceStrings [ "markupsafe" ] [ "MarkupSafe"] old.pname; };
  });

  pyyaml = renameLiteral "PyYAML";

  pillow = let
    pillowOverride = self: super: drv: drv.overrideAttrs(old: {
      nativeBuildInputs = [ pkgs.pkgconfig ]
        ++ old.nativeBuildInputs;
      buildInputs = with pkgs; [ freetype libjpeg zlib libtiff libwebp tcl lcms2 ]
        ++ old.buildInputs;
    });
  in composeOverrides [ renameCapital pillowOverride ];

  pytest = addSetupTools;

  pytest-mock = addSetupTools;

  six = addSetupTools;

  py = addSetupTools;

  zipp = addSetupTools;

  importlib-metadata = composeOverrides [ renameUnderscore addSetupTools ];

  importlib-resources = composeOverrides [ renameUnderscore ];

  typing-extensions = renameUnderscore;

  pluggy = addSetupTools;

  pre-commit = renameUnderscore;

  jsonschema = addSetupTools;

  jinja2 = renameCapital;

  python-dateutil = addSetupTools;

  pygments = renameCapital;

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
