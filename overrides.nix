{
  pkgs,
  python,
  pythonPackages,
}:

{

  pytest = (drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      pythonPackages.setuptools_scm
    ];
  }));

  six = (drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      pythonPackages.setuptools_scm
    ];
  }));

  py = (drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      pythonPackages.setuptools_scm
    ];
  }));

  zipp = (drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      pythonPackages.setuptools_scm
    ];
  }));

  importlib-metadata = (drv: drv.overrideAttrs(old: {
    src = pythonPackages.fetchPypi {
      pname = "importlib_metadata";
      version = old.version;
      sha256 = old.src.outputHash;
    };

    buildInputs = old.buildInputs ++ [
      pythonPackages.setuptools_scm
    ];
  }));

  pluggy = (drv: drv.overrideAttrs(old: {
    buildInputs = old.buildInputs ++ [
      pythonPackages.setuptools_scm
    ];
  }));

}
