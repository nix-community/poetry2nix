#!/usr/bin/env nix-shell
#! nix-shell ./update.nix -i python3
import subprocess
import requests
import shutil
import json
from os.path import (
    abspath,
    dirname,
    join,
)
import os


if __name__ == "__main__":
    workdir = dirname(abspath(__file__))

    rev = requests.get(
        "https://api.github.com/repos/python-poetry/poetry/releases/latest"
    ).json()["name"]

    p = subprocess.run(
        [
            "nix-prefetch-url",
            "--unpack",
            f"https://github.com/python-poetry/poetry/archive/refs/tags/{rev}.tar.gz",
        ],
        stdout=subprocess.PIPE,
        check=True,
    )

    with open(join(workdir, "src.json"), "w") as f:
        f.write(
            json.dumps(
                {
                    "owner": "python-poetry",
                    "repo": "poetry",
                    "rev": rev,
                    "sha256": p.stdout.decode().strip(),
                    "fetchSubmodules": True,
                },
                indent=2,
            )
        )

    src = (
        subprocess.run(
            [
                "nix-build",
                "--no-out-link",
                "--expr",
                "with import <nixpkgs> {}; fetchFromGitHub (lib.importJSON ./src.json)",
            ],
            check=True,
            stdout=subprocess.PIPE,
        )
        .stdout.decode()
        .strip()
    )

    for f in ["poetry.lock", "pyproject.toml"]:
        shutil.copy(join(src, f), join(workdir, f))
        os.chmod(join(workdir, f), 0o664)

    subprocess.run(["poetry", "lock"], check=True)

    # Build poetry and check updated version matches extracted rev
    assert (
        subprocess.run(
            ["nix-shell", join(workdir, "update.nix"), "--run", "poetry --version"],
            check=True,
            stdout=subprocess.PIPE,
        )
        .stdout.decode()
        .split()[-1]
        == rev
    )
