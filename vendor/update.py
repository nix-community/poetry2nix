#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3
import subprocess
import shutil
import json
import os


# Skip parts of the tree which aren't used in poetry2nix
SKIP_FILES = [
    "renderers.nix",
    "project.nix",
    "pep723.nix",
    "validators.nix",
    "scripts.nix",
]


if __name__ == "__main__":
    store_path = json.loads(
        subprocess.check_output(
            [
                "nix-instantiate",
                "--eval",
                "--json",
                "--expr",
                'builtins.fetchGit { url = "git@github.com:nix-community/pyproject.nix.git"; }',
            ]
        )
    )

    try:
        shutil.rmtree("pyproject.nix")
    except FileNotFoundError:
        pass

    os.mkdir("pyproject.nix")
    os.mkdir("pyproject.nix/lib")

    shutil.copy(f"{store_path}/default.nix", f"pyproject.nix/default.nix")

    # Copy lib/
    for filename in os.listdir(f"{store_path}/lib"):
        if filename.startswith("test") or not filename.endswith(".nix") or filename in SKIP_FILES:
            continue
        shutil.copy(f"{store_path}/lib/{filename}", f"pyproject.nix/lib/{filename}")
