#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 poetry

# Run code generation used by poetry2nix

from poetry.packages.utils.utils import SUPPORTED_EXTENSIONS
import json

EXT_FILE = 'extensions.json'

if __name__ == '__main__':
    with open(EXT_FILE, 'w') as f:
        ext = set(ext.lstrip('.') for ext in SUPPORTED_EXTENSIONS)
        ext.add('egg')
        f.write(json.dumps(sorted(ext), indent=2) + '\n')
