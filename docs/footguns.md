# Foot Guns

Although poetry2nix is an excellent choice and tool for packaging a Python
application with Nix there are ways you can subtly put yourself in a
situation that looks troublesome.

## Overriding package versions

Ideally all versions of a package that poetry2nix is bringing in are found in `poetry.lock` file. This means for someone familiar with the Python environment they can easily understand the dependencies being brought in.

If you chose to however _override the package version_ for a particular dependency, you can have a package that has surprising behaviors to those unfamiliar with Nix.

Suppose you had the following `poetry.lock` file:
```toml
[[package]]
name = "foobar"
version = "1.0"
description = "A dummy package"
optional = false
python-versions = ">=3.7"
files = [
    {file = "foobar-1.0-py3-none-any.whl", hash = "sha256:ae74fb96c20a0277a1d615f1e4d73c8414f5a98db8b799a7931d1582f3390c28"},
]
```

Suppose we override the version in our Nix file as follows:
```nix
let poetryOverrides = self: super: {
    foobar = super.foobar.overridePythonAttrs (old: rec {
      version = "2.0";
      src = super.pkgs.fetchFromGitHub {
        owner = "fakerepo";
        repo = "foobar";
        rev = "refs/tags/${version}";
        sha256 = lib.fakeSha256;
      };
    });
  };
in
poetry2nix.mkPoetryApplication {
  projectDir = ../.;
  overrides = poetry2nix.overrides.withDefaults poetryOverrides;
}
```

It _might surprise you_ that the poetry application will build successfully **but** the version that is selected for the package `foobar` is **2.0** although the lockfile says otherwise.

**tl;dr;** the lockfile is not the real source of truth for what version of a package is selected.