#!/usr/bin/env python
# Patch out urls that have .whl

import argparse
import sys

import tomlkit


def main(input, output):
    data = tomlkit.loads(input.read())

    try:
        deps = data["tool"]["poetry"]["dependencies"]
    except KeyError:
        pass
    else:
        for dep in deps.values():
            if isinstance(dep, dict):
                url = dep.get("url", None)
                if url is None or not url.endswith("whl"):
                    continue
                dep["version"] = "*"
                dep.pop("url", None)
                dep.pop("develop", None)

    output.write(tomlkit.dumps(data))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument(
        "-i",
        "--input",
        type=argparse.FileType("r"),
        default=sys.stdin,
        help="Location from which to read input TOML",
    )
    p.add_argument(
        "-o",
        "--output",
        type=argparse.FileType("w"),
        default=sys.stdout,
        help="Location to write output TOML",
    )
    p.add_argument(
        "-f",
        "--fields-to-remove",
        nargs="*",
        help="The fields to remove from the dependency's TOML",
    )

    args = p.parse_args()
    if args.fields_to_remove != ["url"]:
        print(
            f"WARN: url-whl ignoring fields_to_remove ({args.fields_to_remove})",
            file=sys.stderr)
    main(args.input, args.output)
