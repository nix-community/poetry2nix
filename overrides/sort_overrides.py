# This script sorts the overrides in default.nix alphabetically.
# The region to sort is tagged with 'begin/end auto sort'
# This is regex based, double check the results
import re


def sort_nix_definitions(file_path):
    with open(file_path, "r") as file:
        content = file.read()

    lines = content.split("\n")
    start = None
    stop = None
    for ii, line in enumerate(lines):
        if "#### begin auto sort" in line:
            start = ii + 1
            break
    for ii, line in enumerate(lines):
        if "#### end auto sort" in line:
            stop = ii
            break
    if start is None:
        raise ValueError("begin not found")
    if stop is None:
        raise ValueError("end not found")

    lines_to_sort = lines[start:stop]
    print(start, stop)
    print(lines_to_sort[0])

    blocks = []
    inside = False
    block = ""
    for line in lines_to_sort:
        if re.match("^        (# )?([a-zA-Z0-9-]+|$) = ", line):
            if block:
                blocks.append(block)
            block = line + "\n"
            # print(line)
        else:
            block += line + "\n"
        # else:
        #     if line == "  );" or line == "  });":
        #         inside = False
        #         block += line + "\n"
        #         blocks.append(block)
    if block:
        blocks.append(block)
    print("found", len(blocks), "overrides")
    blocks = [x.rstrip() for x in blocks]

    # Sort matches alphabetically
    sorted_matches = sorted(blocks)
    sorted_matches = ["\n\n".join(sorted_matches)]

    out = lines[:start] + sorted_matches + lines[stop:]
    out = "\n".join(out)

    with open("default.nix", "w") as file:
        file.write(out)


# Example usage
sort_nix_definitions("default.nix")
