[![](https://github.com/nix-community/poetry2nix/workflows/CI/badge.svg)](https://github.com/nix-community/poetry2nix/actions?query=branch%3Amaster+workflow%3ACI)

# poetry2nix
_poetry2nix_ turns [Poetry](https://poetry.eustace.io/) projects into Nix derivations without the need to actually write Nix expressions. It does so by parsing `pyproject.toml` and `poetry.lock` and converting them to Nix derivations on the fly.

## API

The _poetry2nix_ public API consists of the following attributes:

- [mkPoetryApplication](#mkPoetryApplication): Creates a Python application.
- [mkPoetryEnv](#mkPoetryEnv): Creates a Python environment with an interpreter and all packages from `poetry.lock`.
- [mkPoetryPackages](#mkPoetryPackages): Creates an attribute set providing access to the generated packages and other artifacts.
- [defaultPoetryOverrides](#defaultPoetryOverrides): A set of bundled overrides fixing problems with Python packages.
- [overrides.withDefaults](#overrideswithDefaults): A convenience function for specifying overrides on top of the defaults.
- [overrides.withoutDefaults](#overrideswithoutDefaults): A convenience function for specifying overrides without defaults.
- [cleanPythonSources](#cleanPythonSources): A function to create a source filter for python projects.

### mkPoetryApplication

Creates a Python application using the Python interpreter specified based on the designated poetry project and lock files. `mkPoetryApplication` takes an attribute set with the following attributes (attributes without default are mandatory):

- **projectDir**: path to the root of the project.
- **src**: project source (_default_: `cleanPythonSources { src = projectDir; }`).
- **pyproject**: path to `pyproject.toml` (_default_: `projectDir + "/pyproject.toml"`).
- **poetrylock**: `poetry.lock` file path (_default_: `projectDir + "/poetry.lock"`).
- **overrides**: Python overrides to apply (_default_: `[defaultPoetryOverrides]`).
- **meta**: application [meta](https://nixos.org/nixpkgs/manual/#chap-meta) data (_default:_ `{}`).
- **python**: The Python interpreter to use (_default:_ `pkgs.python3`).

Other attributes are passed through to `buildPythonApplication`.

#### Example
```nix
poetry2nix.mkPoetryApplication {
    projectDir = ./.;
}
```

See [./pkgs/poetry/default.nix](./pkgs/poetry/default.nix) for a working example.

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

Note: If you need to perform overrides on the application, use `app.dependencyEnv.override { app = app.override { ... }; }`. See [./tests/dependency-environment/default.nix](./tests/dependency-environment/default.nix) for a full example.

### mkPoetryEnv
Creates an environment that provides a Python interpreter along with all dependencies declared by the designated poetry project and lock files. Also allows package sources of an application to be installed in editable mode for fast development. `mkPoetryEnv` takes an attribute set with the following attributes (attributes without default are mandatory):

- **projectDir**: path to the root of the project.
- **pyproject**: path to `pyproject.toml` (_default_: `projectDir + "/pyproject.toml"`).
- **poetrylock**: `poetry.lock` file path (_default_: `projectDir + "/poetry.lock"`).
- **overrides**: Python overrides to apply (_default_: `[defaultPoetryOverrides]`).
- **python**: The Python interpreter to use (_default:_ `pkgs.python3`).
- **editablePackageSources**: A mapping from package name to source directory, these will be installed in editable mode (_default:_ `{}`).

#### Example
```nix
poetry2nix.mkPoetryEnv {
    projectDir = ./.;
}
```

See [./tests/env/default.nix](./tests/env/default.nix) for a working example.

```nix
poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    editablePackageSources = {
        my-app = ./src;
    };
}
```

See [./tests/editable/default.nix](./tests/editable/default.nix) for a working example of an editable package.

### mkPoetryPackages
Creates an attribute set of the shape `{ python, poetryPackages, pyProject, poetryLock }`. Where `python` is the interpreter specified, `poetryPackages` is a list of all generated python packages, `pyProject` is the parsed `pyproject.toml` and `poetryLock` is the parsed `poetry.lock` file. `mkPoetryPackages` takes an attribute set with the following attributes (attributes without default are mandatory):

- **projectDir**: path to the root of the project.
- **pyproject**: path to `pyproject.toml` (_default_: `projectDir + "/pyproject.toml"`).
- **poetrylock**: `poetry.lock` file path (_default_: `projectDir + "/poetry.lock"`).
- **overrides**: Python overrides to apply (_default_: `[defaultPoetryOverrides]`).
- **python**: The Python interpreter to use (_default:_ `pkgs.python3`).

#### Example
```nix
poetry2nix.mkPoetryPackages {
    projectDir = ./.;
    python = python35;
}
```

### defaultPoetryOverrides

_poetry2nix_ bundles a set of default overrides that fix problems with various Python packages. These overrides are implemented in [overrides.nix](./overrides.nix).

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
  p2nix = poetry2nix.overrideScope' (self: super: {

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
        poetry2nix = super.poetry2nix.overrideScope' (p2nixself: p2nixsuper: {

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

## Contributing

Contributions to this project are welcome in the form of GitHub PRs. Please consider the following before creating PRs:

- This project uses [nixpkgs-fmt](https://github.com/nix-community/nixpkgs-fmt) for formatting the Nix code. You can use
`nix-shell --run "nixpkgs-fmt .` to format everything.
- If you are planning to make any considerable changes, you should first present your plans in a GitHub issue so it can be discussed.
- If you add new features please consider adding tests.


## License
_poetry2nix_ is released under the terms of the MIT license.
