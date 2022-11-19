# Edge cases
## Preamble
The python ecosystem has a very long history.
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

#### ModuleNotFoundError: No module named 'poetry'
**Conditions:** you have declared a dependency on git repository with the python package.
And this package uses poetry as a build tool.
So since `poetry2nix` cannot obtain this dependency in form of a wheel, it needs to build it from the source by calling pip.
But pip requires poetry to build this package. And that’s when an error occurs.

**Solution:** in order to make dependency build we need to override it build dependencies by adding poetry  package to it.

**Example:** let's consider situation when our package has declared `git` dependency in `pyproject.toml` on `extralib`, which uses poetry to be built.
And we have this declaration in our Nix definition:
```
poetry2nix.mkPoetryApplication {
  projectDir = ./.;
}
```
And trying to build it get us next error log
<details>
  <summary>error log (click to expand)</summary>

```
Sourcing python-catch-conflicts-hook.sh
Sourcing python-remove-bin-bytecode-hook.sh
Sourcing pip-build-hook
Using pipBuildPhase
Using pipShellHook
Sourcing pip-install-hook
Using pipInstallPhase
Sourcing python-imports-check-hook.sh
Using pythonImportsCheckPhase
Sourcing python-namespaces-hook
@nix { "action": "setPhase", "phase": "unpackPhase" }
unpacking sources
unpacking source archive /nix/store/f2mb5sy6vxm81sy5apzvbxmnvj8f62la-source
source root is source
setting SOURCE_DATE_EPOCH to timestamp 315619200 of file source/extralib/utils.py
@nix { "action": "setPhase", "phase": "patchPhase" }
patching sources
Removing path dependencies
Finished removing path dependencies
Removing git dependencies
Finished removing git dependencies
@nix { "action": "setPhase", "phase": "configurePhase" }
configuring
no configure script, doing nothing
@nix { "action": "setPhase", "phase": "buildPhase" }
building
Executing pipBuildPhase
Creating a wheel...
WARNING: The directory '/homeless-shelter/.cache/pip' or its parent directory is not owned or is not writable by the current user. The cache has been disabled. Check the permissions and owner of that directory. If executing pip with sudo, you should use sudo's -H flag.
Ignoring indexes: https://pypi.org/simple
Created temporary directory: /build/pip-ephem-wheel-cache-oluqv9z9
Created temporary directory: /build/pip-req-tracker-6nbzvq94
Initialized build tracking at /build/pip-req-tracker-6nbzvq94
Created build tracker: /build/pip-req-tracker-6nbzvq94
Entered build tracker: /build/pip-req-tracker-6nbzvq94
Created temporary directory: /build/pip-wheel-ecarqqhj
Processing /build/source
  Created temporary directory: /build/pip-req-build-thqopu_1
  DEPRECATION: A future pip version will change local packages to be built in-place without first copying to a temporary directory. We recommend you use --use-feature=in-tree-build to test your packages with this new behavior before it becomes the default.
   pip 21.3 will remove support for this functionality. You can find discussion regarding this at https://github.com/pypa/pip/issues/7555.
  Added file:///build/source to build tracker '/build/pip-req-tracker-6nbzvq94'
    Created temporary directory: /build/pip-modern-metadata-5otx3b_0
    Running command /nix/store/rppr9s436950i1dlzknbmz40m2xqqnxc-python3-3.9.9/bin/python3.9 /nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_vendor/pep517/in_process/_in_process.py prepare_metadata_for_build_wheel /build/tmp8cfof26u
    Preparing wheel metadata ... done
ERROR: Exception:
Traceback (most recent call last):
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/cli/base_command.py", line 180, in _main
    status = self.run(options, args)
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/cli/req_command.py", line 205, in wrapper
    return func(self, options, args)
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/commands/wheel.py", line 142, in run
    requirement_set = resolver.resolve(
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/resolution/resolvelib/resolver.py", line 103, in resolve
    r = self.factory.make_requirement_from_install_req(
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/resolution/resolvelib/factory.py", line 429, in make_requirement_from_install_req
    cand = self._make_candidate_from_link(
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/resolution/resolvelib/factory.py", line 200, in _make_candidate_from_link
    self._link_candidate_cache[link] = LinkCandidate(
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/resolution/resolvelib/candidates.py", line 306, in __init__
    super().__init__(
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/resolution/resolvelib/candidates.py", line 151, in __init__
    self.dist = self._prepare()
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/resolution/resolvelib/candidates.py", line 234, in _prepare
    dist = self._prepare_distribution()
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/resolution/resolvelib/candidates.py", line 317, in _prepare_distribution
    return self._factory.preparer.prepare_linked_requirement(
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/operations/prepare.py", line 508, in prepare_linked_requirement
    return self._prepare_linked_requirement(req, parallel_builds)
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/operations/prepare.py", line 570, in _prepare_linked_requirement
    dist = _get_prepared_distribution(
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/operations/prepare.py", line 60, in _get_prepared_distribution
    abstract_dist.prepare_distribution_metadata(finder, build_isolation)
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/distributions/sdist.py", line 36, in prepare_distribution_metadata
    self.req.prepare_metadata()
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/req/req_install.py", line 549, in prepare_metadata
    self.metadata_directory = self._generate_metadata()
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/req/req_install.py", line 534, in _generate_metadata
    return generate_metadata(
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_internal/operations/build/metadata.py", line 31, in generate_metadata
    distinfo_dir = backend.prepare_metadata_for_build_wheel(
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_vendor/pep517/wrappers.py", line 184, in prepare_metadata_for_build_wheel
    return self._call_hook('prepare_metadata_for_build_wheel', {
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_vendor/pep517/wrappers.py", line 275, in _call_hook
    raise BackendUnavailable(data.get('traceback', ''))
pip._vendor.pep517.wrappers.BackendUnavailable: Traceback (most recent call last):
  File "/nix/store/11wvwr8f2dp4x8xjnrgqn3inmh418apn-python3.9-pip-21.1.3/lib/python3.9/site-packages/pip/_vendor/pep517/in_process/_in_process.py", line 86, in _build_backend
    obj = import_module(mod_path)
  File "/nix/store/rppr9s436950i1dlzknbmz40m2xqqnxc-python3-3.9.9/lib/python3.9/importlib/__init__.py", line 127, in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
  File "<frozen importlib._bootstrap>", line 1030, in _gcd_import
  File "<frozen importlib._bootstrap>", line 1007, in _find_and_load
  File "<frozen importlib._bootstrap>", line 972, in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 228, in _call_with_frames_removed
  File "<frozen importlib._bootstrap>", line 1030, in _gcd_import
  File "<frozen importlib._bootstrap>", line 1007, in _find_and_load
  File "<frozen importlib._bootstrap>", line 972, in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 228, in _call_with_frames_removed
  File "<frozen importlib._bootstrap>", line 1030, in _gcd_import
  File "<frozen importlib._bootstrap>", line 1007, in _find_and_load
  File "<frozen importlib._bootstrap>", line 972, in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 228, in _call_with_frames_removed
  File "<frozen importlib._bootstrap>", line 1030, in _gcd_import
  File "<frozen importlib._bootstrap>", line 1007, in _find_and_load
  File "<frozen importlib._bootstrap>", line 984, in _find_and_load_unlocked
ModuleNotFoundError: No module named 'poetry'

Removed file:///build/source from build tracker '/build/pip-req-tracker-6nbzvq94'
Removed build tracker: '/build/pip-req-tracker-6nbzvq94'
```
</details>

In order to be able to build `extralib` we should modify our nix definition as follows:
```
poetry2nix.mkPoetryApplication {
  projectDir = ./.;
  overrides = poetry2nix.defaultPoetryOverrides.extend ( self: super: {
    extralib = super.extralib.overridePythonAttrs (
      old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ self.poetry ];
      }
    );
  });
}
```
This override will instruct underlying build logic to include additional build dependency into inputs of `extralib`.
