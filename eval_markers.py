#!/usr/bin/env python3


class extra(str):
    def __eq__(self, other):
        return True


if __name__ == "__main__":
    import argparse
    import json
    from packaging.markers import parse_marker, default_environment, _evaluate_markers

    p = argparse.ArgumentParser()
    p.add_argument("marker", type=str)
    args = p.parse_args()

    marker = args.marker
    if not marker:
        res = "true"
    else:
        parsed = parse_marker(marker)
        env = default_environment()
        env["extra"] = extra()
        evaled = _evaluate_markers(parsed, env)
        res = json.dumps(evaled)

    print(res)
