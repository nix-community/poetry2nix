[![](https://gitlab.com/nix-community/poetry2nix/badges/master/pipeline.svg)](https://gitlab.com/nix-community/poetry2nix/-/jobs)

# poetry2nix
_poetry2nix_ turns [Poetry](https://poetry.eustace.io/) projects into Nix derivations without the need to actually write Nix expressions. It does so by parsing `pyproject.toml` and `poetry.lock` and converting them to Nix derivations on the fly.

## API

The _poetry2nix_ public API consists of the following attributes:

- [mkPoetryApplication](#mkPoetryApplication): Creates a Python application.
- [mkPoetryEnv](#mkPoetryEnv): Creates a Python environment with an interpreter and all packages from `poetry.lock`.
- [mkPoetryPackages](#mkPoetryPackages): Creates an attribute set providing access to the generated packages and other artifacts.
- [defaultPoetryOverrides](#defaultPoetryOverrides): A set of bundled overrides fixing problems with Python packages.
- [overrides.withDefaults](#overrides.withDefaults): A convenience function for specifying overrides on top of the defaults.
- [overrides.withoutDefaults](#overrides.withoutDefaults): A convenience function for specifying overrides without defaults.

### mkPoetryApplication

Creates a Python application using the Python interpreter specified based on the designated poetry project and lock files. `mkPoetryApplication` takes an attribute set with the following attributes (attributes without default are mandatory):

- **projectDir**: path to the root of the project.
- **src**: project source (_default_: `lib.cleanSource projectDir`).
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

### mkPoetryEnv
Creates an environment that provides a Python interpreter along with all dependencies declared by the designated poetry project and lock files. `mkPoetryEnv` takes an attribute set with the following attributes (attributes without default are mandatory):

- **projectDir**: path to the root of the project.
- **pyproject**: path to `pyproject.toml` (_default_: `projectDir + "/pyproject.toml"`).
- **poetrylock**: `poetry.lock` file path (_default_: `projectDir + "/poetry.lock"`).
- **overrides**: Python overrides to apply (_default_: `[defaultPoetryOverrides]`).
- **python**: The Python interpreter to use (_default:_ `pkgs.python3`).

#### Example
```nix
poetry2nix.mkPoetryEnv {
    projectDir = ./.;
}
```

See [./tests/env/default.nix](./tests/env/default.nix) for a working example.

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

## Contributing

Contributions to this project are welcome in the form of GitHub PRs. Please consider the following before creating PRs:

- This project uses [nixpkgs-fmt](https://github.com/nix-community/nixpkgs-fmt) for formatting the Nix code. You can use
`nix-shell --run "nixpkgs-fmt ." to format everything.
- If you are planning to make any considerable changes, you should first present your plans in a GitHub issue so it can be discussed.
- If you add new features please consider adding tests.


## License
_poetry2nix_ is released under the terms of the MIT license.
