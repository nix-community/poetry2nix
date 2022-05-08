remove-@kind@-dependencies-hook() {
    if ! test -f pyproject.toml; then
        return
    fi

    echo "Removing @kind@ dependencies"

    # Tell poetry not to resolve special dependencies. Any version is fine!
    @pythonInterpreter@ \
    @pyprojectPatchScript@ \
      --fields-to-remove @fields@ < pyproject.toml > pyproject.formatted.toml

    mv pyproject.formatted.toml pyproject.toml

    echo "Finished removing @kind@ dependencies"
}

postPatchHooks+=(remove-@kind@-dependencies-hook)
