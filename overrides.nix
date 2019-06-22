let
  addSetupTools = self: drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      self.setuptools_scm
    ];
  });

in {

  pytest = addSetupTools;

  six = addSetupTools;

  py = addSetupTools;

  zipp = addSetupTools;

  importlib-metadata = (self: drv: drv.overrideAttrs(old: {
    src = self.fetchPypi {
      pname = "importlib_metadata";
      version = old.version;
      sha256 = old.src.outputHash;
    };

    buildInputs = old.buildInputs ++ [
      self.setuptools_scm
    ];
  }));

  pluggy = addSetupTools;

}
