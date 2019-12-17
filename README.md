[![](https://gitlab.com/nix-community/poetry2nix/badges/master/pipeline.svg)](https://gitlab.com/nix-community/poetry2nix/-/jobs)

# poetry2nix
poetry2nix turns [Poetry](https://poetry.eustace.io/) projects into Nix derivations without the need to actually write Nix expressions. It does so by parsing `pyproject.toml` and `poetry.lock` and converting them to Nix derivations on the fly.

## Usage

poetry2nix has 2 main use-cases:

- `mkPoetryApplication`: For building poetry based Python applications.
- `mkPoetryEnv`: For creating a python environment with the dependencies of a `poetry.lock` file.

## Notes

Whenever possible poetry2nix uses source archives to install Python dependencies. Some packages however only provide binaries in
the form of `.whl` files. If no source archives are provided, `poetry2nix` tries to select an appropriate `manylinux` binary and
automatically adds the required dependencies to the python package. **Note** that for manylinux packages to work you need to use
very recent nixpkgs.

## Examples

### mkPoetryApplication

```nix
poetry2nix.mkPoetryApplication {
    src = lib.cleanSource ./.;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    python = python3;
}
```

See [./pkgs/poetry/default.nix](./pkgs/poetry/default.nix) for a working example.

### mkPoetryEnv

```nix
poetry2nix.mkPoetryEnv {
    poetrylock = ./poetry.lock;
    python = python3;
}
```

The above expression returns a package with a python interpreter and all packages specified
in the `poetry.lock` lock file. See [./tests/env/default.nix](./tests/env/default.nix) for a working example.

## Contributing

Contributions to this project are welcome in the form of GitHub PRs. Please consider the following before creating PRs:

- This project uses [nixpkgs-fmt](https://github.com/nix-community/nixpkgs-fmt) for fomatting the Nix code. You can use
`nix-shell --run "nixpkgs-fmt ." to format everything.
- If you are planning to make any considerable changes, you should first present your plans in a GitHub issue so it can be discussed.
- If you add new features please consider adding tests.


## License
`poetry2nix` is released under the terms of the MIT license.
