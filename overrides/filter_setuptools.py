import json
from pathlib import Path

input = json.loads(Path("build-systems.json").read_text())

output = {}
for k, v in input.items():
    if isinstance(v, list):
        v = [x for x in v if x != "setuptools" and x != "setuptools-scm"]
        if v:
            output[k] = v
    else:
        output[k] = v

print(len(output))

Path("build-systems.json").write_text(json.dumps(output, indent=2))
