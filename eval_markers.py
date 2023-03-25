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

    parsed = parse_marker(args.marker)
    env = default_environment()
    env["extra"] = extra()
    evaled = _evaluate_markers(parsed, env)
    res = json.dumps(evaled)

    print(res)
