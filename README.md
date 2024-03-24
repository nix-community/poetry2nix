[![](https://github.com/nix-community/poetry2nix/workflows/CI/badge.svg)](https://github.com/nix-community/poetry2nix/actions?query=branch%3Amaster+workflow%3ACI)
[![Chat on Matrix](https://matrix.to/img/matrix-badge.svg)](https://matrix.to/#/#poetry2nix:blad.is)

# poetry2nix
_poetry2nix_ turns [Poetry](https://python-poetry.org/) projects into Nix derivations without the need to actually write Nix expressions. It does so by parsing `pyproject.toml` and `poetry.lock` and converting them to Nix derivations on the fly.

For more information, see [the announcement post on the Tweag blog](https://www.tweag.io/blog/2020-08-12-poetry2nix/).

## Table of contents
- [API](#api)
- [FAQ](#FAQ)
- [How-to guides](#how-to-guides)
- [Using the flake](#using-the-flake)
- [Contributing](#contributing)
- [Contact](#contact)
- [Acknowledgements](#acknowledgements)
- [License](#license)

## API

The _poetry2nix_ public API consists of the following attributes:

- [mkPoetryApplication](#mkpoetryapplication): Creates a Python application.
- [mkPoetryEnv](#mkpoetryenv): Creates a Python environment with an interpreter and all packages from `poetry.lock`.
- [mkPoetryPackages](#mkpoetrypackages): Creates an attribute set providing access to the generated packages and other artifacts.
- [mkPoetryScriptsPackage](#mkpoetryscriptspackage): Creates a package containing the scripts from `tool.poetry.scripts` of the `pyproject.toml`.
- [mkPoetryEditablePackage](#mkpoetryeditablepackage): Creates a package containing editable sources. Changes in the specified paths will be reflected in an interactive nix-shell session without the need to restart it.
- [defaultPoetryOverrides](#defaultpoetryoverrides): A set of bundled overrides fixing problems with Python packages.
- [overrides.withDefaults](#overrideswithdefaults): A convenience function for specifying overrides on top of the defaults.
- [overrides.withoutDefaults](#overrideswithoutdefaults): A convenience function for specifying overrides without defaults.
- [cleanPythonSources](#cleanpythonsources): A function to create a source filter for python projects.

### mkPoetryApplication

Creates a Python application using the Python interpreter specified based on the designated poetry project and lock files. `mkPoetryApplication` takes an attribute set with the following attributes (attributes without default are mandatory):

- **projectDir**: path to the root of the project.
- **src**: project source (_default_: `cleanPythonSources { src = projectDir; }`).
- **pyproject**: path to `pyproject.toml` (_default_: `projectDir + "/pyproject.toml"`).
- **poetrylock**: `poetry.lock` file path (_default_: `projectDir + "/poetry.lock"`).
- **overrides**: Python overrides to apply (_default_: `defaultPoetryOverrides`).
- **meta**: application [meta](https://nixos.org/nixpkgs/manual/#chap-meta) data (_default:_ `{}`).
- **python**: The Python interpreter to use (_default:_ `pkgs.python3`).
- **preferWheels** : Use wheels rather than sdist as much as possible (_default_: `false`).
- **groups**: Which Poetry 1.2.0+ dependency groups to install (_default_: `[ ]`).
- **checkGroups**: Which Poetry 1.2.0+ dependency groups to run unit tests (_default_: `[  "dev" ]`).
- **extras**: Which Poetry `extras` to install (_default_: `[ "*" ]`, all extras).

Other attributes are passed through to `buildPythonApplication`.

Make sure to add in your `pyproject.toml` the py-object for your `main()`. Otherwise, the result is empty.

```toml
[tool.poetry.scripts]
poetry = "poetry.console.application:main"
```

#### Example
```nix
poetry2nix.mkPoetryApplication {
    projectDir = ./.;
}
```

#### Dependency environment

The resulting derivation also has the passthru attribute `dependencyEnv`, which is an environment with a python interpreter, all non-development dependencies and your application.
This can be used if your application doesn't provide any binaries on its own and instead relies on dependencies binaries to call its modules (as is often the case with `celery` or `gunicorn`).
For example, if your application defines a CLI for the module `admin` and a gunicorn app for the module `web`, a working `default.nix` would contain

```nix
let
    app = poetry2nix.mkPoetryApplication {
        projectDir = ./.;
    };
in app.dependencyEnv
```

After building this expression, your CLI and app can be called with these commands

```shell
$ result/bin/python -m admin
$ result/bin/gunicorn web:app
```

If you prefer to build a single binary that runs `gunicorn web:app`, use [`pkgs.writeShellApplication`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/trivial-builders.nix#L317) for a simple wrapper.

Note: If you need to perform overrides on the application, use `app.dependencyEnv.override { app = app.override { ... }; }`. See [./tests/dependency-environment/default.nix](./tests/dependency-environment/default.nix) for a full example.

### mkPoetryEnv
Creates an environment that provides a Python interpreter along with all dependencies declared by the designated poetry project and lock files. Also allows package sources of an application to be installed in editable mode for fast development. `mkPoetryEnv` takes an attribute set with the following attributes (attributes without default are mandatory):

- **projectDir**: path to the root of the project.
- **pyproject**: path to `pyproject.toml` (_default_: `projectDir + "/pyproject.toml"`).
- **poetrylock**: `poetry.lock` file path (_default_: `projectDir + "/poetry.lock"`).
- **overrides**: Python overrides to apply (_default_: `defaultPoetryOverrides`).
- **python**: The Python interpreter to use (_default:_ `pkgs.python3`).
- **editablePackageSources**: A mapping from package name to source directory, these will be installed in editable mode. Note that path dependencies with `develop = true` will be installed in editable mode unless explicitly passed to `editablePackageSources` as `null`.  (_default:_ `{}`).
- **extraPackages**: A function taking a Python package set and returning a list of extra packages to include in the environment. This is intended for packages deliberately not added to `pyproject.toml` that you still want to include. An example of such a package may be `pip`. (_default:_ `(ps: [ ])`).
- **preferWheels** : Use wheels rather than sdist as much as possible (_default_: `false`).
- **groups**: Which Poetry 1.2.0+ dependency groups to install (_default_: `[ "dev" ]`).
- **checkGroups**: Which Poetry 1.2.0+ dependency groups to run unit tests (_default_: `[  "dev" ]`).
- **extras**: Which Poetry `extras` to install (_default_: `[ "*" ]`, all extras).

#### Example
```nix
poetry2nix.mkPoetryEnv {
    projectDir = ./.;
}
```

See [./tests/env/default.nix](./tests/env/default.nix) for a working example.

#### Example with editable packages
```nix
poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    editablePackageSources = {
        my-app = ./src;
    };
}
```

See [./tests/editable/default.nix](./tests/editable/default.nix) for a working example of an editable package.

#### Example shell.nix
The `env` attribute of the attribute set created by `mkPoetryEnv` contains a shell environment.

```nix
{ pkgs ? import <nixpkgs> {} }:
let
  myAppEnv = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    editablePackageSources = {
      my-app = ./src;
    };
  };
in myAppEnv.env
```

#### Example shell.nix with external dependencies
For a shell environment including external dependencies, override the `env` to add dependency packages (for example, `pkgs.hello`) as build inputs.
```nix
{ pkgs ? import <nixpkgs> {} }:
let
  myAppEnv = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    editablePackageSources = {
      my-app = ./src;
    };
  };
in myAppEnv.env.overrideAttrs (oldAttrs: {
  buildInputs = [ pkgs.hello ];
})
```

### mkPoetryPackages
Creates an attribute set of the shape `{ python, poetryPackages, pyProject, poetryLock }`. Where `python` is the interpreter specified, `poetryPackages` is a list of all generated python packages, `pyProject` is the parsed `pyproject.toml` and `poetryLock` is the parsed `poetry.lock` file. `mkPoetryPackages` takes an attribute set with the following attributes (attributes without default are mandatory):

- **projectDir**: path to the root of the project.
- **pyproject**: path to `pyproject.toml` (_default_: `projectDir + "/pyproject.toml"`).
- **poetrylock**: `poetry.lock` file path (_default_: `projectDir + "/poetry.lock"`).
- **overrides**: Python overrides to apply (_default_: `defaultPoetryOverrides`).
- **python**: The Python interpreter to use (_default:_ `pkgs.python3`).
- **editablePackageSources**: A mapping from package name to source directory, these will be installed in editable mode (_default:_ `{}`).
- **preferWheels** : Use wheels rather than sdist as much as possible (_default_: `false`).
- **groups**: Which Poetry 1.2.0+ dependency groups to install (_default_: `[ ]`).
- **checkGroups**: Which Poetry 1.2.0+ dependency groups to run unit tests (_default_: `[  "dev" ]`).
- **extras**: Which Poetry `extras` to install (_default_: `[ "*" ]`, all extras).

#### Example
```nix
poetry2nix.mkPoetryPackages {
    projectDir = ./.;
    python = python35;
}
```

### mkPoetryScriptsPackage
Creates a package containing the scripts from `tool.poetry.scripts` of the `pyproject.toml`:

- **projectDir**: path to the root of the project.
- **pyproject**: path to `pyproject.toml` (_default_: `projectDir + "/pyproject.toml"`).
- **python**: The Python interpreter to use (_default:_ `pkgs.python3`).

#### Example
```nix
poetry2nix.mkPoetryScriptsPackage {
    projectDir = ./.;
    python = python35;
}
```

### mkPoetryEditablePackage
Creates a package containing editable sources. Changes in the specified paths will be reflected in an interactive nix-shell session without the need to restart it:

- **projectDir**: path to the root of the project.
- **pyproject**: path to `pyproject.toml` (_default_: `projectDir + "/pyproject.toml"`).
- **python**: The Python interpreter to use (_default:_ `pkgs.python3`).
- **editablePackageSources**: A mapping from package name to source directory, these will be installed in editable mode (_default:_ `{}`).

#### Example
```nix
poetry2nix.mkPoetryEditablePackage {
    projectDir = ./.;
    python = python35;
    editablePackageSources = {
        my-app = ./src;
    };
}
```

### defaultPoetryOverrides

_poetry2nix_ bundles a set of default overrides that fix problems with various Python packages. These overrides are implemented in [overrides](./overrides/default.nix).

### overrides.withDefaults
Returns a list containing the specified overlay and `defaultPoetryOverrides`.

Takes an attribute set with the following attributes (attributes without default are mandatory):
- **src**: project source directory

#### Example

```nix
poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    overrides = poetry2nix.overrides.withDefaults (self: super: { foo = null; });
}
```
See [./tests/override-support/default.nix](./tests/override-support/default.nix) for a working example.

### overrides.withoutDefaults
Returns a list containing just the specified overlay, ignoring `defaultPoetryOverrides`.

#### Example

```nix
poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    overrides = poetry2nix.overrides.withoutDefaults (self: super: { foo = null; });
}
```

### cleanPythonSources
Provides a source filtering mechanism that:
- Filters gitignore's
- Filters pycache/pyc files
- Uses cleanSourceFilter to filter out .git/.hg, .o/.so, editor backup files & nix result symlinks

#### Example

```nix
poetry2nix.cleanPythonSources {
    src = ./.;
}
```

### Creating a custom Poetry2nix instance
Sometimes when it can be convenient to create a custom instance of `poetry2nix` with a different set of default overrides.

#### Example
```nix
let
  # self & super refers to poetry2nix
  p2nix = poetry2nix.overrideScope (self: super: {

    # pyself & pysuper refers to python packages
    defaultPoetryOverrides = super.defaultPoetryOverrides.extend (pyself: pysuper: {

      my-custom-pkg = super.my-custom-pkg.overridePythonAttrs (oldAttrs: { });

    });

  });

in
p2nix.mkPoetryApplication {
  projectDir = ./.;
}
```

or as a [nixpkgs overlay](https://nixos.org/nixpkgs/manual/#chap-overlays):
```nix
let
  pkgs = import <nixpkgs> {
    overlays = [
      # self & super refers to nixpkgs
      (self: super: {

        # p2self & p2super refers to poetry2nix
        poetry2nix = super.poetry2nix.overrideScope (p2nixself: p2nixsuper: {

          # pyself & pysuper refers to python packages
          defaultPoetryOverrides = p2nixsuper.defaultPoetryOverrides.extend (pyself: pysuper: {

            my-custom-pkg = super.my-custom-pkg.overridePythonAttrs (oldAttrs: { });

          });

        });
      })

    ];
  };

in pkgs.poetry2nix.mkPoetryApplication {
  projectDir = ./.;
}
```


## FAQ

**Q.** Does poetry2nix install wheels our sdists?

**A.** By default, poetry2nix installs from source. If you want to give precedence to wheels, look at the `preferWheel` and `preferWheels` attributes.

**Q.** Does poetry2nix use package definitions from nixpkgs' Python package set?

**A.** poetry2nix overlays packages taken from the `poetry.lock` file on top of nixpkgs, in such a way that overlaid packages in nixpkgs are completely ignored.
Any package that is used, but isn't in the `poetry.lock` file (most commonly [build dependencies](https://github.com/nix-community/poetry2nix/blob/master/overrides/build-systems.json)) is taken from nixpkgs.

**Q.** How to prefer wheel installation for a single package?

**A.** Override it and set `preferWheel = true` in that single package:

```nix
poetry2nix.mkPoetryApplication {
  projectDir = ./.;
  overrides = poetry2nix.overrides.withDefaults (final: prev: {
    # Notice that using .overridePythonAttrs or .overrideAttrs wont work!
    some-dependency = prev.some-dependency.override {
      preferWheel = true;
    };
  });
}
```

**Q.** I'm experiencing one of the following errors, what do I do?

- ModuleNotFoundError: No module named 'setuptools'
- ModuleNotFoundError: No module named 'pdm'
- ModuleNotFoundError: No module named 'setuptools-scm'
- ModuleNotFoundError: No module named 'poetry-core'
- ModuleNotFoundError: No module named 'flit'
- ModuleNotFoundError: No module named 'flit-core'
- ModuleNotFoundError: No module named 'flit-scm'

**A.** Have a look at the following document [edgecase.md](./docs/edgecases.md)

## How-to guides
- [Package and deploy Python apps faster with Poetry and Nix](https://www.youtube.com/watch?v=TbIHRHy7_JM)
This is a short (11 minutes) video tutorial by [Steve Purcell](https://github.com/purcell/) from [Tweag](https://tweag.io) walking you through how to get started with a small web development project.

## Using the flake

For the experimental flakes functionality we provide _poetry2nix_ as a flake providing an overlay
to use with [nixpkgs](https://nixos.org/nixpkgs/manual). Additionally, the flake provides
a flake template to quickly start using _poetry2nix_ in a project:

```sh
nix flake init --template github:nix-community/poetry2nix
```
## Contributing

Contributions to this project are welcome in the form of GitHub PRs. Please consider the following before creating PRs:

- This project uses [nixpkgs-fmt](https://github.com/nix-community/nixpkgs-fmt) for formatting the Nix code. You can use
`nix-shell --run "nixpkgs-fmt ."` to format everything.
- If you are planning to make any considerable changes, you should first present your plans in a GitHub issue so it can be discussed.
- If you add new features please consider adding tests. You can run them locally as follows:

```bash
nix-build --keep-going --show-trace tests/default.nix
```

To list test names:

```bash
nix eval --impure --expr 'let pkgs = import <nixpkgs> {}; in pkgs.lib.attrNames (import ./tests/default.nix {})'
```

To run specific tests, add `--attr NAME` to the `nix-build` command above. For example, to run the `bcrypt` and `jq` tests:

```bash
nix-build --attr bcrypt --attr jq --keep-going --show-trace tests/default.nix
```

To test with a specific channel:

```bash
nix-build --expr 'with import <unstable> {}; callPackage ./tests/default.nix {}'
```

To sort `overrides/build-systems.json` according to the [`sort-build-systems` job](.github/workflows/ci.yml), patch the source with the output of the "Check format" step, like this: `nix-shell [omitted] | patch -p0`.

## Contact
We have a Matrix room at [#poetry2nix:blad.is](https://matrix.to/#/#poetry2nix:blad.is).

## Acknowledgements
Development of `poetry2nix` has been supported by [Tweag](https://tweag.io).

## License
_poetry2nix_ is released under the terms of the MIT license.
