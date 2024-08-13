[![](https://github.com/nix-community/poetry2nix/workflows/CI/badge.svg)](https://github.com/nix-community/poetry2nix/actions?query=branch%3Amaster+workflow%3ACI)
[![Chat on Matrix](https://matrix.to/img/matrix-badge.svg)](https://matrix.to/#/#poetry2nix:blad.is)

# poetry2nix

_poetry2nix_ turns [Poetry](https://python-poetry.org/) projects into Nix derivations without the need to actually write Nix expressions. It does so by parsing `pyproject.toml` and `poetry.lock` and converting them to Nix derivations on the fly.

For more information, see [the announcement post on the Tweag blog](https://www.tweag.io/blog/2020-08-12-poetry2nix/).

## Quickstart Non-flake

You can turn your Python application into a Nix package with a few lines
by adding a `default.nix` next to your `pyproject.toml` and `poetry.lock` files:

```nix
# file: default.nix
let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  # Let all API attributes like "poetry2nix.mkPoetryApplication" 
  # use the packages and versions (python3, poetry etc.) from our pinned nixpkgs above
  # under the hood:
  poetry2nix = import sources.poetry2nix { inherit pkgs; };
  myPythonApp = poetry2nix.mkPoetryApplication { projectDir = ./.; };
in
myPythonApp
```

The Nix code being executed by `import sources.poetry2nix { inherit pkgs; }`
is [./default.nix](./default.nix).
The resulting `poetry2nix` attribute set contains (only) the [API attributes](#api) like
`mkPoetryApplication`.

Hint:
This example assumes that `nixpkgs` and `poetry2nix` are managed and pinned by
the handy [niv tool](https://github.com/nmattia/niv). In your terminal just run:

```shell
nix-shell -p niv
niv init
niv add nix-community/poetry2nix
```

You can then build your Python application with Nix by running:

```shell
nix-build default.nix
```

Finally, you can run your Python application from the new `./result` symlinked folder:

```shell
# replace <script> with the name in the [tool.poetry.scripts] section of your pyproject.toml
./result/bin/<script>
```

## Quickstart flake.nix

If your project uses the experimental `flake.nix` schema, you don't need niv.
This repository provides _poetry2nix_ as a flake as well for you to import
as a flake input. For example:

```nix
# file: flake.nix
{
  description = "Python application packaged using poetry2nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.poetry2nix.url = "github:nix-community/poetry2nix";

  outputs = { self, nixpkgs, poetry2nix }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # create a custom "mkPoetryApplication" API function that under the hood uses
      # the packages and versions (python3, poetry etc.) from our pinned nixpkgs above:
      inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication;
      myPythonApp = mkPoetryApplication { projectDir = ./.; };
    in
    {
      apps.${system}.default = {
        type = "app";
        # replace <script> with the name in the [tool.poetry.scripts] section of your pyproject.toml
        program = "${myPythonApp}/bin/<script>";
      };
    };
}
```

You can then (build and) run your Python app with

```shell
nix run .
```

A larger real-world setup can be found in [./templates/app/flake.nix](./templates/app/flake.nix).
This example is also exported as a flake template so that you can start your _poetry2nix_ project
conveniently through:

```shell
nix flake init --template github:nix-community/poetry2nix
```

Additionally, this project flake provides an [overlay](https://wiki.nixos.org/wiki/Overlays)
to merge `poetry2nix` into your `pkgs` and access it as `pkgs.poetry2nix`.
Just replace the three lines `pkgs = ...`, `inherit ...` and `myPythonApp = ...` above with:

```nix
pkgs = nixpkgs.legacyPackages.${system}.extend poetry2nix.overlays.default;
myPythonApp = pkgs.poetry2nix.mkPoetryApplication { projectDir = self; };
```

## Table of contents

- [API](#api)
- [FAQ](#faq)
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
- **checkGroups**: Which Poetry 1.2.0+ dependency groups to install (independently of **groups**) to run unit tests (_default_: `[ "dev" ]`).
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
./result/bin/python -m admin
./result/bin/gunicorn web:app
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
- **checkGroups**: Which Poetry 1.2.0+ dependency groups to install (independently of **groups**) to run unit tests (_default_: `[ "dev" ]`).
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
- **checkGroups**: Which Poetry 1.2.0+ dependency groups to install (independently of **groups**) to run unit tests (_default_: `[ "dev" ]`).
- **extras**: Which Poetry `extras` to install (_default_: `[ "*" ]`, all extras).

#### Example

```nix
poetry2nix.mkPoetryPackages {
    projectDir = ./.;
    python3 = python39;
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
    python3 = python39;
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
    python3 = python39;
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
    overrides = poetry2nix.overrides.withDefaults (final: prev: { foo = null; });
}
```

See [./tests/override-support/default.nix](./tests/override-support/default.nix) for a working example.

### overrides.withoutDefaults

Returns a list containing just the specified overlay, ignoring `defaultPoetryOverrides`.

#### Example

```nix
poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    overrides = poetry2nix.overrides.withoutDefaults (final: prev: { foo = null; });
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
  # final & prev refers to poetry2nix
  p2nix = poetry2nix.overrideScope (final: prev: {

    # pyself & pyprev refers to python packages
    defaultPoetryOverrides = prev.defaultPoetryOverrides.extend (pyfinal: pyprev: {

      my-custom-pkg = prev.my-custom-pkg.overridePythonAttrs (oldAttrs: { });

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
      # final & prev refers to nixpkgs
      (final: prev: {

        # p2nixfinal & p2nixprev refers to poetry2nix
        poetry2nix = prev.poetry2nix.overrideScope (p2nixfinal: p2nixprev: {

          # pyfinal & pyprev refers to python packages
          defaultPoetryOverrides = p2nixprev.defaultPoetryOverrides.extend (pyfinal: pyprev: {

            my-custom-pkg = prev.my-custom-pkg.overridePythonAttrs (oldAttrs: { });

          });

        });
      })

    ];
  };

in pkgs.poetry2nix.mkPoetryApplication {
  projectDir = ./.;
}
```

## Using private Python package repositories with authentication

Poetry by default downloads Python packages (wheels, sources, etc.) from [PyPI](https://pypi.org)
but supports to specify one or more alternative repositories in a
["package source" section](https://python-poetry.org/docs/repositories/#package-sources)
in the `pyproject.toml` file:

```toml
[[tool.poetry.source]]
name = "private-repository"
url = "https://example.org/simple/"
priority = "primary"
...
```

Poetry then bakes the individual source repository urls for each Python package together with
a cryptographic hash of the package into its `poetry.lock` file.
This is great for reproducibility as Poetry knows where to download packages from later
and can ensure that the packages haven't been modified.

__Poetry2nix__ downloads the same packages from the same repository urls in the lock file
and reuses the hashes. However, many private Python repositories require authentication
with credentials like username and password token, especially in companies.

While Poetry supports several methods of authentication like through
a [NETRC file](https://everything.curl.dev/usingcurl/netrc.html)
[environment variables](https://python-poetry.org/docs/repositories/#publishing-to-a-private-repository)
a [custom crendentials file](https://python-poetry.org/docs/repositories/#configuring-credentials)
and others,
__poetry2nix only supports one: the `NETRC` file method__ that secretly adds credentials to your
http calls to the repository url, e.g. `https://example.org/simple/`.

For this to work, __follow these three steps__:

1. __Create or locate your `NETRC` file__ into your computer, usually in your home folder `/home/user/<username>/.netrc`
or `/etc/nix/netrc` with credentials like:

```netrc
machine https://example.org
login <repository-username>
password <repository-password-or-token>
```

2. __Mount the `NETRC` file into the Nix build sandbox__ with Nix
[extra-sandbox-paths](https://nixos.org/manual/nix/stable/command-ref/conf-file#conf-extra-sandbox-paths)
setting; otherwise __poetry2nix__ is not able to access that file
from within the Nix sandbox.
You can mount the file either through the global Nix/NixOS config, usually `/etc/nix/nix.conf`:

```ini
# file: nix.conf
extra-sandbox-paths /etc/nix/netrc`
```

This is not recommended as you expose your secrets to all Nix builds.

Better just mount it for single, specific __poetry2nix__ builds directly in the terminal:

```shell
# non-flake project
nix-build --option extra-sandbox-paths /etc/nix/netrc default.nix
# flake project
nix build . --extra-sandbox-paths /etc/nix/netrc
```

Note that the username you're executing this command with must be a
["trusted-user"](https://nixos.org/manual/nix/stable/command-ref/conf-file#conf-trusted-users)
in the global Nix/NixOS config, usually `/etc/nix/nix.conf`:

```ini
# file: nix.conf
trusted-users <username>
```

If you are not a trusted user, this
[extra setting will be silently ignored](https://github.com/NixOS/nix/issues/6115#issuecomment-1060626260)
and package downloads will fail.

3. Tell __poetry2nix__ where to find the `NETRC` file inside the Nix sandbox.
For that you have to __pass an environment variable  called `NETRC` into the sandbox__ containing the path
to the file. Depending on whether you use flakes or not you have the following options:

__For flakes__ the only option is to add the environment variable to the "nix-daemon", the process
that actually creates sandboxes and performs builds on your behalf.

On NixOS you can add the env variable to the nix-daemon through its [systemd](https://systemd.io/) configuration:

```nix
systemd.services.nix-daemon = {
  serviceConfig = {
    Environment = "NETRC=/etc/nix/netrc";
  };
};
```

This environment variable will automatically be passed to all your builds so you can
keep using the build commands as before;

```shell
# non-flake project
nix-build --option extra-sandbox-paths /etc/nix/netrc default.nix
# flake project
nix build . --extra-sandbox-paths /etc/nix/netrc
```

__For a non-flake project__ you can alternatively pass the `NETRC` path value through
a fake Nix search path `-I NETRC=<netrc-path>` argument in the terminal; such a search path doesn't work with flakes.
__poetry2nix__ contains special code to forward this variable as an environment variable into any Python sandbox.

```shell
# non-flake project
nix-build -I NETRC=/etc/nix/netrc --option extra-sandbox-paths /etc/nix/netrc default.nix
```

Note: The alternative to pass the `NETRC` path environment variable
into the sandbox via the (impureEnvVars setting](https://nixos.org/manual/nix/stable/language/advanced-attributes.html##adv-attr-impureEnvVars)
doesn't work.

## FAQ

**Q.** Does poetry2nix install wheels or sdists?

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
    # Notice that using .overridePythonAttrs or .overrideAttrs won't work!
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

## Contributing

Contributions to this project are welcome in the form of GitHub PRs. Please consider the following before creating PRs:

- You can use `nix fmt` to format everything and sort `overrides/build-systems.json`.
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

## Contact

We have a Matrix room at [#poetry2nix:blad.is](https://matrix.to/#/#poetry2nix:blad.is).

## Acknowledgements

Development of `poetry2nix` has been supported by [Tweag](https://tweag.io).

## License

_poetry2nix_ is released under the terms of the MIT license.
