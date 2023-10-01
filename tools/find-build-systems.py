#!/usr/bin/env python
from concurrent.futures import ThreadPoolExecutor
from itertools import chain
from posix import cpu_count
import re
from typing import (
    Dict,
    List,
    Set,
)
from pathlib import Path
import subprocess
import pynixutil
import tempfile
import json
import sys


# While we (im)patiently await a fix for https://github.com/python-poetry/poetry/pull/2794
# and require overrides to fix the issue we can at least regain a little bit of automation by inheriting these from nixpkgs
#
# This script evaluates nixpkgs and extracts a a few well known build systems and dumps them in a json file we can consume in the poetry2nix overrides


# All known PEP-517 (or otherwise) build systems
with (Path(__file__).parent.parent / "known-build-systems.json").open() as _fd:
    BUILD_SYSTEMS = json.load(_fd)


# Skip these attributes as they have more complex conditions manually
SKIP_ATTRS = {
    "typing-extensions",
    "argon2-cffi",
    "packaging",
    "poetry",
    "flit-core",
    "jsonschema",
    "platformdirs",
    "traitlets",
}


def normalize(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def find_known_systems() -> Dict[str, str]:
    """Create a map from attribute to drvPath for known build systems"""

    expr = """let
      pkgs = import <nixpkgs> { };
      py = pkgs.python3.pkgs;
      attrs = [ %s ];
    in builtins.foldl' (
      acc: attr: acc // {
        ${attr} = py.${attr}.drvPath;
      }
    ) { } attrs""" % " ".join(
        f'"{s}"' for s in BUILD_SYSTEMS
    )

    p = subprocess.run(
        ["nix-instantiate", "--eval", "--expr", f"builtins.toJSON ({expr})"],
        stdout=subprocess.PIPE,
    )
    return json.loads(json.loads(p.stdout))


def yield_drvs():
    """Yield all drvs from the python3 set"""

    with tempfile.NamedTemporaryFile(mode="w") as f:
        f.write(
            """
          let
            pkgs = import <nixpkgs> { };
            pythonPackages = pkgs.python3.pkgs;
          in builtins.removeAttrs pythonPackages [
            "pkgs"
            "pythonPackages"
            "__splicedPackages"
          ]
        """
        )
        f.flush()

        p = subprocess.Popen(
            ["nix-eval-jobs", "--workers", str(cpu_count()), f.name],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )

        for l in p.stdout:
            j = json.loads(l)
            if "error" in j:
                continue
            try:
                yield (j["attr"], j["drvPath"])
            except KeyError:
                pass

        returncode = p.wait()
        if returncode != 0:
            raise ValueError(f"Eval returned: {returncode}")


def get_build_systems(known_systems) -> Dict[str, List[str]]:
    def check_drv(drv_path) -> List[str]:
        systems: List[str] = []
        with open(drv_path) as f:
            drv = pynixutil.drvparse(f.read())

        input_drvs: Set[str] = set(drv.input_drvs.keys())

        for attr, build_system in known_systems.items():
            if build_system in input_drvs:
                systems.append(attr)

        return systems

    with ThreadPoolExecutor() as e:
        futures = {
            attr: e.submit(check_drv, drv_path)
            for attr, drv_path in yield_drvs()
            if attr not in SKIP_ATTRS
        }
        build_systems = {attr: future.result() for attr, future in futures.items()}

    # Second pass, filter out any empty lists
    return {attr: systems for attr, systems in build_systems.items() if systems}


BLOCKLIST = {"poetry", "poetry-core"}


def merge_systems(s):
    simple = {i for i in s if isinstance(i, str)}
    complex = [i for i in s if isinstance(i, dict)]
    complex_names = {i["buildSystem"] for i in complex}
    new_simple = simple - complex_names
    return complex + sorted(list(new_simple))


def merge(prev_content, new_content):
    content = {}
    for attr, systems in chain(prev_content.items(), new_content.items()):
        attr = normalize(attr)
        s = content.setdefault(attr, [])
        for system in systems:
            s.append(system)

    # Return with sorted data
    return {
        attr: merge_systems(content[attr])
        for attr in sorted(content.keys())
        if attr not in BLOCKLIST
    }


def main():
    outfile = sys.argv[1]

    try:
        with open(outfile) as f:
            prev_content = json.load(f)
    except FileNotFoundError:
        prev_content = {}

    known_systems = find_known_systems()

    build_systems = get_build_systems(known_systems)

    # Unlike nixpkgs we want overrides to be strictly additive by
    # merging content from previous generations with new generations
    merged = merge(prev_content, build_systems)

    with open(outfile, mode="w") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
