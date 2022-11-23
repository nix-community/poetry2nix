# Edge cases

## Preamble

The Python ecosystem has a very long history.
Over the years, an uncountable number of modules have been created, but more importantly, the assembly technology of these modules has changed many times.
`ez_install`, `setuptools`, `distutils`, eggs, `pip`, wheels, PEP-518, PEP-517, `flit`, `poetry`.
All this diversity creates great difficulties.
Poetry, on the one hand, being a build system, can abandon the setuptools and distutils formats, but at the same time, being a dependency installation and management system, it must support all current distribution technologies.
And it can do this without revealing the internal structure and the machinery behind curtains.
In other words, when you use Poetry, both `setuptools`, `pip` and other build tools can be used to install some modules, and this happens without formally declaring dependence on these tools.

All these factors can cause the module not to be assembled or installed in a certain environment.
Nix is a much stricter ecosystem, it has more formal requirements, but at the same time more guarantees.
And since `poetry2nix` relies on Nix and its strict rules in its work, there are many rough edges and inaccuracies in the metadata on pypi.org leads to errors.
This is very sad, and we will inevitably face the fact that some modules can not be installed, can not be built, or just cause errors, have unnecessary or missing direct and transitive dependencies.
However, Nix is a very flexible system that allows you to modify some aspects of the module with pinpoint accuracy, without changing the source code of the module (and sometimes changing it).
This is what this section is dedicated to.
We have tried to collect here and describe typical errors and ways to eliminate them.

## Cases

#### ModuleNotFoundError: No module named 'PACKAGENAME'

**Conditions:** You have declared a dependency in a repository.
And this package uses `PACKAGENAME` as a build tool. Where `PACKAGENAME` most likely is one of the tools mentioned above (`setuptools`, `pdm`, etc.).
So since `poetry2nix` cannot obtain this dependency in form of a wheel, it needs to build it from the source by calling pip.
But pip requires `PACKAGENAME` to build this package. And that’s when an error occurs.

**Solution:** In order to make the dependency build, we need to override its build dependencies by adding the `PACKAGENAME` package to it.

**Example:** Let's consider the situation when our package has declared `django-floppyforms` as a dependency in `pyproject.toml`, which uses `PACKAGENAME` to be built.
And we have this declaration in our Nix definition:

``` nix
poetry2nix.mkPoetryApplication {
  projectDir = ./.;
}
```

And trying to build it results in the following error log
<details>
  <summary>error log (click to expand)</summary>

```
Sourcing python-remove-tests-dir-hook
Sourcing python-catch-conflicts-hook.sh
Sourcing python-remove-bin-bytecode-hook.sh
Sourcing pip-install-hook
Using pipInstallPhase
Sourcing python-imports-check-hook.sh
Using pythonImportsCheckPhase
Sourcing python-namespaces-hook
Sourcing pip-build-hook
Using pipBuildPhase
Using pipShellHook
@nix { "action": "setPhase", "phase": "unpackPhase" }
unpacking sources
unpacking source archive /nix/store/w1gk95sf5lknw0mxav5gsvcijcwfqkwh-django-floppyforms-1.9.0.tar.gz
source root is django-floppyforms-1.9.0
setting SOURCE_DATE_EPOCH to timestamp 1589942379 of file django-floppyforms-1.9.0/setup.cfg
@nix { "action": "setPhase", "phase": "patchPhase" }
patching sources
@nix { "action": "setPhase", "phase": "configurePhase" }
configuring
no configure script, doing nothing
@nix { "action": "setPhase", "phase": "buildPhase" }
building
Executing pipBuildPhase
Creating a wheel...
WARNING: The directory '/homeless-shelter/.cache/pip' or its parent directory is not owned or is not writable by the current user. The cache has been disabled. Check the permissions and owner of that directory. If executing pip with sudo, you should use sudo's -H flag.
Processing /build/django-floppyforms-1.9.0
  Running command Preparing metadata (pyproject.toml)
  Preparing metadata (pyproject.toml) ... done
ERROR: Exception:
Traceback (most recent call last):
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/cli/base_command.py", line 167, in exc_logging_wrapper
    status = run_func(*args)
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/cli/req_command.py", line 247, in wrapper
    return func(self, options, args)
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/commands/wheel.py", line 145, in run
    requirement_set = resolver.resolve(reqs, check_supported_wheels=True)
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/resolution/resolvelib/resolver.py", line 73, in resolve
    collected = self.factory.collect_root_requirements(root_reqs)
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/resolution/resolvelib/factory.py", line 491, in collect_root_requirements
    req = self._make_requirement_from_install_req(
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/resolution/resolvelib/factory.py", line 453, in _make_requirement_from_install_req
    cand = self._make_candidate_from_link(
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/resolution/resolvelib/factory.py", line 206, in _make_candidate_from_link
    self._link_candidate_cache[link] = LinkCandidate(
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/resolution/resolvelib/candidates.py", line 297, in __init__
    super().__init__(
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/resolution/resolvelib/candidates.py", line 162, in __init__
    self.dist = self._prepare()
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/resolution/resolvelib/candidates.py", line 231, in _prepare
    dist = self._prepare_distribution()
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/resolution/resolvelib/candidates.py", line 308, in _prepare_distribution
    return preparer.prepare_linked_requirement(self._ireq, parallel_builds=True)
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/operations/prepare.py", line 438, in prepare_linked_requirement
    return self._prepare_linked_requirement(req, parallel_builds)
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/operations/prepare.py", line 524, in _prepare_linked_requirement
    dist = _get_prepared_distribution(
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/operations/prepare.py", line 68, in _get_prepared_distribution
    abstract_dist.prepare_distribution_metadata(
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/distributions/sdist.py", line 61, in prepare_distribution_metadata
    self.req.prepare_metadata()
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/req/req_install.py", line 533, in prepare_metadata
    self.metadata_directory = generate_metadata(
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/operations/build/metadata.py", line 35, in generate_metadata
    distinfo_dir = backend.prepare_metadata_for_build_wheel(metadata_dir)
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_internal/utils/misc.py", line 706, in prepare_metadata_for_build_wheel
    return super().prepare_metadata_for_build_wheel(
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_vendor/pep517/wrappers.py", line 188, in prepare_metadata_for_build_wheel
    return self._call_hook('prepare_metadata_for_build_wheel', {
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_vendor/pep517/wrappers.py", line 332, in _call_hook
    raise BackendUnavailable(data.get('traceback', ''))
pip._vendor.pep517.wrappers.BackendUnavailable: Traceback (most recent call last):
  File "/nix/store/85xz0a1v6kk26c8a78pckbylhkdmlb6g-python3.10-pip-22.2.2/lib/python3.10/site-packages/pip/_vendor/pep517/in_process/_in_process.py", line 89, in _build_backend
    obj = import_module(mod_path)
  File "/nix/store/qc8rlhdcdxaf6dwbvv0v4k50w937fyzj-python3-3.10.8/lib/python3.10/importlib/__init__.py", line 126, in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
  File "<frozen importlib._bootstrap>", line 1050, in _gcd_import
  File "<frozen importlib._bootstrap>", line 1027, in _find_and_load
  File "<frozen importlib._bootstrap>", line 992, in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
  File "<frozen importlib._bootstrap>", line 1050, in _gcd_import
  File "<frozen importlib._bootstrap>", line 1027, in _find_and_load
  File "<frozen importlib._bootstrap>", line 1004, in _find_and_load_unlocked
ModuleNotFoundError: No module named 'setuptools'

error (ignored): error: cannot unlink '/tmp/nix-build-python3.10-django-4.1.3.drv-1/Django-4.1.3': Directory not empty
error: 1 dependencies of derivation '/nix/store/hz4b87s99s1lwiz2m0vwilhlh6rlfj64-python3-3.10.8-env.drv' failed to build
error: 1 dependencies of derivation '/nix/store/60gaxbdf11lhaj9xg50cf0rr6x5v8v1z-nix-shell-env.drv' failed to build
```

As you can see on the fourth last line it's missing `setuptools` which in this case is our missing `PACKAGENAME`.

</details>

In order to be able to build `django-floppyforms` we should modify our nix definition as follows:

``` nix
poetry2nix.mkPoetryApplication {
  projectDir = ./.;
  overrides = poetry2nix.defaultPoetryOverrides.extend
    (self: super: {
      django-floppyforms = super.django-floppyforms.overridePythonAttrs
      (
        old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ];
        }
      );
    });
}
```

This override will instruct the underlying build logic to include the additional build dependency into the inputs of `django-floppyforms`.
It might help to know that you don't need to use the full package name like `python39Packages.setuptools` but can just use `setuptools` directly.
However you have to use the name like defined in `Nixpkgs` so something like `flit_scm` becomes `flit-scm`.

It can happen that you need multiple overrides for your project, just work through one after the other and your project should build at the end.
Your file might then look something like this:

``` nix
poetry2nix.mkPoetryApplication {
  projectDir = ./.;
  overrides = poetry2nix.defaultPoetryOverrides.extend
    (self: super: {
      first-dependency = super.first-dependency.overridePythonAttrs
      (
        old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ super.buildtools ];
        }
      );
      second-dependency = super.second-dependency.overridePythonAttrs
      (
        old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ super.pdm ];
        }
      );
    });
}
```

We recommend that you contribute your changes to `poetry2nix` so that other users can profit from them as well.
The file with the upstream overrides can be found here: https://github.com/nix-community/poetry2nix/blob/master/overrides/build-systems.json
