#!/usr/bin/env bash
# Generates `poetry_<dep>_<version>.lock` from `pyproject.toml` and an overriding
# `versions.json` (the original `pyproject.toml` MUST accept `poetry.lock` 
# WITHOUT MODIFICATION, NOT enforced by this script)
#
# This is useful to ensure a package is well-integrated across multiple versions
#
# Requires `nixpkgs#yq-go`, `nixpkgs#nix`, `nixpkgs#poetry`
set -euo pipefail

# The first command-line argument is the path to the pyproject.toml file
pyprojectFile="${1:-"${PWD}/pyproject.toml"}"
# The second command-line argument is a JSON string with the dependency-version mapping
depVersionsJson="${2:-"${PWD}/versions.json"}"

# Function to update pyproject.toml with the new version for a given dependency
update_pyproject() {
  local dep="${1}"
  local version="$2"
  tmp=$(mktemp -d)
  echo "update ${dep} @ ${version} at $tmp"
  pyproject_json="${tmp}/pyproject.json" # since yq can't output complex toml
  pyproject_toml="${tmp}/pyproject.toml"
  yq -oj ".tool.poetry.dependencies[\"$dep\"] = \"$version\"" "$pyprojectFile" >"$pyproject_json"
  nix-build --expr "let pkgs = import <nixpkgs> {}; in (pkgs.formats.toml {}).generate \"dummy\" (builtins.fromJSON (builtins.readFile ${pyproject_json}))" -o $pyproject_toml

  poetry_lock="${tmp}/poetry.lock"
  pushd $tmp && poetry lock && popd && cp "$poetry_lock" "${PWD}/poetry_${dep}_${version}.lock"
}

pyproject_pin_check() {
  # note that previously pinned `poetry.lock` from `pyproject.toml` might
  # be acceptable, but say, a future (now current) version of `foo` now
  # depends on `bar >= 1.0.0`, where our `pyproject.toml` pins `bar = 0.4.0`,
  # `update_pyproject` will fail. This checks for the sanity of `pyproject.toml`
  # before we variate the versions within this `pyproject.toml`
  tmp=$(mktemp -d)
  cp "$pyprojectFile" "${tmp}/pyproject.toml"
  pushd $tmp && poetry lock && popd
}

pyproject_pin_check

pids=()
# Iterate over depVersions to generate new poetry.lock files
while read -r dep_version; do
  dep=$(echo "$dep_version" | jq -r '.dep')
  version=$(echo "$dep_version" | jq -r '.version')
  echo "dep = $dep"
  echo "version = $version"

  # Update pyproject.toml with the new version for the dependency
  update_pyproject "$dep" "$version" &
  pids+=($!)

done < <(jq -c '.[]' "$depVersionsJson")

for pid in "${pids[@]}"; do
    wait "$pid"
done
