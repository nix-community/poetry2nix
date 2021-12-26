#!/usr/bin/env python3
import subprocess
import json
import sys


expr = 'builtins.toJSON (builtins.attrNames (import ./tests {}))'


if __name__ == '__main__':
    attrs = json.loads(json.loads(subprocess.check_output([
        "nix-instantiate",
        "--eval",
        "--expr",
        expr
    ])))

    matrix = [
        {
            "attr": attr
        }
        for attr in attrs
    ]

    sys.stdout.write("::set-output name=matrix::")
    json.dump({"include": matrix}, sys.stdout)
    sys.stdout.flush()
