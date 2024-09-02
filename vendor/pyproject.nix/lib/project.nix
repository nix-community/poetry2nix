{
  pep621,
  poetry,
  pip,
  lib,
  renderers,
  validators,
  ...
}:

let
  inherit (builtins) mapAttrs;

  # Map over renderers and inject project argument.
  # This allows for a user interface like:
  # project.renderers.buildPythonPackage { } where project is already curried.
  curryProject =
    attrs: project:
    lib.mapAttrs (
      _: func: args:
      func (args // { inherit project; })
    ) attrs;

  # Package manager specific extensions.
  # Remap extension fields to optional-dependencies
  uvListPaths = {
    "tool.uv.dev-dependencies" = "dev-dependencies";
  };
  pdmAttrPaths = [ "tool.pdm.dev-dependencies" ];

in
lib.fix (self: {
  /*
    Load dependencies from a PEP-621 pyproject.toml.

    Type: loadPyproject :: AttrSet -> AttrSet

    Example:
      # loadPyproject { pyproject = lib.importTOML }
      {
        dependencies = { }; # Parsed dependency structure in the schema of `lib.pep621.parseDependencies`
        build-systems = [ ];  # Returned by `lib.pep518.parseBuildSystems`
        pyproject = { }; # The unmarshaled contents of pyproject.toml
        projectRoot = null; # Path to project root
        requires-python = null; # requires-python as parsed by pep621.parseRequiresPython
      }
  */
  loadPyproject =
    {
      # The unmarshaled contents of pyproject.toml
      pyproject ? lib.importTOML (projectRoot + "/pyproject.toml"),
      # Example: extrasAttrPaths = [ "tool.pdm.dev-dependencies" ];
      extrasAttrPaths ? [ ],
      # Example: extrasListPaths = { "tool.uv.dependencies.dev-dependencies" = "dev-dependencies"; }
      extrasListPaths ? { },
      # Path to project root
      projectRoot ? null,
    }:
    lib.fix (project: {
      dependencies = pep621.parseDependencies { inherit pyproject extrasAttrPaths extrasListPaths; };
      inherit pyproject projectRoot;
      renderers = curryProject renderers project;
      validators = curryProject validators project;
      requires-python = pep621.parseRequiresPython pyproject;
    });

  /*
    Load dependencies from a uv pyproject.toml.

    Type: loadUVPyproject :: AttrSet -> AttrSet

    Example:
      # loadUVPyproject { projectRoot = ./.; }
      {
        dependencies = { }; # Parsed dependency structure in the schema of `lib.pep621.parseDependencies`
        build-systems = [ ];  # Returned by `lib.pep518.parseBuildSystems`
        pyproject = { }; # The unmarshaled contents of pyproject.toml
        projectRoot = null; # Path to project root
        requires-python = null; # requires-python as parsed by pep621.parseRequiresPython
      }
  */
  loadUVPyproject =
    {
      # The unmarshaled contents of pyproject.toml
      pyproject ? lib.importTOML (projectRoot + "/pyproject.toml"),
      # Path to project root
      projectRoot ? null,
    }:
    self.loadPyproject {
      inherit pyproject projectRoot;
      extrasListPaths = uvListPaths;
    };

  /*
    Load dependencies from a PDM pyproject.toml.

    Type: loadPDMPyproject :: AttrSet -> AttrSet

    Example:
      # loadPyproject { projectRoot = ./.; }
      {
        dependencies = { }; # Parsed dependency structure in the schema of `lib.pep621.parseDependencies`
        build-systems = [ ];  # Returned by `lib.pep518.parseBuildSystems`
        pyproject = { }; # The unmarshaled contents of pyproject.toml
        projectRoot = null; # Path to project root
        requires-python = null; # requires-python as parsed by pep621.parseRequiresPython
      }
  */
  loadPDMPyproject =
    {
      # The unmarshaled contents of pyproject.toml
      pyproject ? lib.importTOML (projectRoot + "/pyproject.toml"),
      # Path to project root
      projectRoot ? null,
      # The unmarshaled contents of pdm.lock
      pdmLock ? lib.importTOML (projectRoot + "/pdm.lock"),
    }:
    self.loadPyproject {
      inherit pyproject projectRoot;
      extrasAttrPaths = pdmAttrPaths;
    }
    // {
      inherit pdmLock;
    };

  /*
    Load dependencies from a Poetry pyproject.toml.

    Type: loadPoetryPyproject :: AttrSet -> AttrSet

    Example:
      # loadPoetryPyproject { projectRoot = ./.; }
      {
        dependencies = { }; # Parsed dependency structure in the schema of `lib.pep621.parseDependencies`
        build-systems = [ ];  # Returned by `lib.pep518.parseBuildSystems`
        pyproject = { }; # The unmarshaled contents of pyproject.toml
        projectRoot = null; # Path to project root
        requires-python = null; # requires-python as parsed by pep621.parseRequiresPython
      }
  */
  loadPoetryPyproject =
    {
      # The unmarshaled contents of pyproject.toml
      pyproject ? lib.importTOML (projectRoot + "/pyproject.toml"),
      # Path to project root
      projectRoot ? null,
      # The unmarshaled contents of poetry.lock
      poetryLock ? lib.importTOML (projectRoot + "/poetry.lock"),
    }:
    let
      pyproject-pep621 = poetry.translatePoetryProject pyproject;
    in
    lib.fix (project: {
      dependencies = poetry.parseDependencies pyproject;
      pyproject = pyproject-pep621;
      pyproject-poetry = pyproject;
      renderers = curryProject renderers project;
      validators = curryProject validators project;
      inherit projectRoot poetryLock;
      requires-python = null;
    });

  /*
    Load dependencies from a requirements.txt.

    Note that as requirements.txt is lacking important project metadata this is incompatible with some renderers.

    Type: loadRequirementsTxt :: AttrSet -> AttrSet

    Example:
      # loadRequirementstxt { requirements = builtins.readFile ./requirements.txt; projectRoot = ./.; }
      {
        dependencies = { }; # Parsed dependency structure in the schema of `lib.pep621.parseDependencies`
        build-systems = [ ];  # Returned by `lib.pep518.parseBuildSystems`
        pyproject = null; # The unmarshaled contents of pyproject.toml
        projectRoot = null; # Path to project root
        requires-python = null; # requires-python as parsed by pep621.parseRequiresPython
      }
  */
  loadRequirementsTxt =
    {
      # The contents of requirements.txt
      requirements ? builtins.readFile (projectRoot + "/requirements.txt"),
      # Path to project root
      projectRoot ? null,
    }:
    lib.fix (project: {
      dependencies = {
        dependencies = map (x: x.requirement) (pip.parseRequirementsTxt requirements);
        extras = { };
        build-systems = [ ];
      };
      pyproject = null;
      renderers = curryProject renderers project;
      validators = curryProject validators project;
      inherit projectRoot;
      requires-python = null;
    });

  /*
    Load dependencies from a either a PEP-621 or Poetry pyproject.toml file.
    This function is intended for 2nix authors that wants to include local pyproject.toml files
    but don't know up front whether they're from Poetry or PEP-621.

    Type: loadPyprojectDynamic :: AttrSet -> AttrSet

    Example:
      # loadPyprojectDynamic { projectRoot = ./.; }
      {
        dependencies = { }; # Parsed dependency structure in the schema of `lib.pep621.parseDependencies`
        build-systems = [ ];  # Returned by `lib.pep518.parseBuildSystems`
        pyproject = { }; # The unmarshaled contents of pyproject.toml
        projectRoot = null; # Path to project root
        requires-python = null; # requires-python as parsed by pep621.parseRequiresPython
      }
  */
  loadPyprojectDynamic =
    {
      # The unmarshaled contents of pyproject.toml
      pyproject ? lib.importTOML (projectRoot + "/pyproject.toml"),
      # Path to project root
      projectRoot ? null,
    }:
    let
      isPoetry = pyproject ? tool.poetry;
      isPep621 = pyproject ? project;
    in
    if isPoetry then
      self.loadPoetryPyproject { inherit pyproject projectRoot; }
    else if isPep621 then
      self.loadPyproject {
        inherit pyproject projectRoot;
        extrasListPaths = uvListPaths;
        extrasAttrPaths = pdmAttrPaths;
      }
    else
      throw "Project is neither Poetry nor PEP-621";
})
