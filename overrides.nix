{ pkgs ? import <nixpkgs> { }}:

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

  # Chain multiple overrides into a single one
  composeOverrides = overrides:
    (self: super: drv: builtins.foldl' (drv: override: override self super drv) drv overrides);

in {

  pytest = addSetupTools;

  six = addSetupTools;

  py = addSetupTools;

  zipp = addSetupTools;

  importlib-metadata = composeOverrides [ renameUnderscore addSetupTools ];

  typing-extensions = renameUnderscore;

  pluggy = addSetupTools;

  jsonschema = addSetupTools;

  lockfile = self: super: drv: drv.overrideAttrs(old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ [ self.pbr ];
  });

}
