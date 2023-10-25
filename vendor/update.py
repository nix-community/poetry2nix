#!/usr/bin/env python3
import subprocess
import shutil
import json
import os


if __name__ == "__main__":
    store_path = json.loads(
        subprocess.check_output(
            [
                "nix-instantiate",
                "--eval",
                "--json",
                "--expr",
                'builtins.fetchGit { url = "git@github.com:adisbladis/pyproject.nix.git"; }',
            ]
        )
    )

    try:
        shutil.rmtree("pyproject.nix")
    except FileNotFoundError:
        pass

    os.mkdir("pyproject.nix")

    for filename in os.listdir(f"{store_path}/lib"):
        if filename.startswith("test") or not filename.endswith(".nix"):
            continue
        shutil.copy(f"{store_path}/lib/{filename}", f"pyproject.nix/{filename}")
