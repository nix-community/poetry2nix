#!/usr/bin/env python
# Patch out path dependencies from a pyproject.json file

import json
import sys

data = json.load(open('pyproject.json', 'r'))

for dep in data['tool']['poetry']['dependencies'].values():
    if isinstance(dep, dict):
        try:
            del dep['path'];
        except KeyError:
            pass
        else:
            dep['version'] = '*'

json.dump(data, sys.stdout, indent=4)
