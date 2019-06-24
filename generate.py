#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3Packages.poetry

# Run code generation used by poetry2nix

from poetry.packages.utils.utils import SUPPORTED_EXTENSIONS
import json

EXT_FILE = 'extensions.json'

if __name__ == '__main__':
    with open(EXT_FILE, 'w') as f:
        ext = sorted(ext.lstrip('.') for ext in SUPPORTED_EXTENSIONS)
        f.write(json.dumps(ext, indent=2))
