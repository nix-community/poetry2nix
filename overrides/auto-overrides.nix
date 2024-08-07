{
  pkgs,
  lib,
}: let
  sharedLibExt = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
  addBuildSystem' = {
    final,
    drv,
    attr,
    extraAttrs ? [],
  }: let
    buildSystem =
      if builtins.isAttrs attr
      then let
        fromIsValid =
          if builtins.hasAttr "from" attr
          then lib.versionAtLeast drv.version attr.from
          else true;
        untilIsValid =
          if builtins.hasAttr "until" attr
          then lib.versionOlder drv.version attr.until
          else true;
        intendedBuildSystem =
          if
            lib.elem attr.buildSystem [
              "cython"
              "cython_0"
            ]
          then (final.python.pythonOnBuildForHost or final.python.pythonForBuild).pkgs.${attr.buildSystem}
          else final.${attr.buildSystem};
      in
        if fromIsValid && untilIsValid
        then intendedBuildSystem
        else null
      else if
        lib.elem attr [
          "cython"
          "cython_0"
        ]
      then (final.python.pythonOnBuildForHost or final.python.pythonForBuild).pkgs.${attr}
      else final.${attr};
  in
    if (attr == "flit-core" || attr == "flit" || attr == "hatchling") && !final.isPy3k
    then drv
    else if drv == null
    then null
    else if !drv ? overridePythonAttrs
    then drv
    else
      drv.overridePythonAttrs (
        old:
        # We do not need the build system for wheels.
          if old ? format && old.format == "wheel"
          then {}
          else if attr == "poetry"
          then {
            # replace poetry
            postPatch =
              (old.postPatch or "")
              + ''
                if [ -f pyproject.toml ]; then
                  toml="$(mktemp)"
                  yj -tj < pyproject.toml | jq --from-file ${./poetry-to-poetry-core.jq} | yj -jt > "$toml"
                  mv "$toml" pyproject.toml
                fi
              '';
            nativeBuildInputs =
              old.nativeBuildInputs
              or []
              ++ [
                final.poetry-core
                final.pkgs.yj
                final.pkgs.jq
              ]
              ++ map (a: final.${a}) extraAttrs;
          }
          else {
            nativeBuildInputs =
              old.nativeBuildInputs
              or []
              ++ lib.optionals (!(builtins.isNull buildSystem)) [buildSystem]
              ++ map (a: final.${a}) extraAttrs;
          }
      );

  buildSystems = lib.importJSON ./build-systems.json;

  extractCargoLock = src:
    pkgs.runCommand "extract-cargolock-${src.name}-${src.version}" {} ''
      mkdir $out
      tar xf ${src}
      CARGO_LOCK_PATH=`find . -name "Cargo.lock" | sort | head -n1`
      if [ -z "$CARGO_LOCK_PATH" ]; then
        echo "Cargo.lock not found in ${src}"
        exit 1
      fi
      cp $CARGO_LOCK_PATH "$out"
    '';
  standardMaturin = {
    outputHashes ? {},
    furtherArgs ? {},
    maturinHook ? pkgs.rustPlatform.maturinBuildHook,
  }: old:
    lib.optionalAttrs (!(old.src.isWheel or false)) (
      {
        cargoDeps = pkgs.rustPlatform.importCargoLock {
          lockFile = ./. + "/cargo.locks/${old.pname}/${old.version}.lock";
        };
        nativeBuildInputs =
          (old.nativeBuildInputs or [])
          ++ [
            pkgs.rustPlatform.cargoSetupHook
            maturinHook
          ]
          ++ (
            if maturinHook == null
            then []
            else []
          )
          ++ (furtherArgs.nativeBuildInputs or []);
      }
      # furtherargs without nativeBuildInputs
      // lib.attrsets.filterAttrs (name: value: name != "nativeBuildInputs") furtherArgs
    );
  offlineMaturinHook = pkgs.callPackage (
    {pkgsHostTarget}:
      pkgs.makeSetupHook {
        name = "offline-maturin-build-hook.sh";
        propagatedBuildInputs = [
          pkgsHostTarget.maturin
          pkgsHostTarget.cargo
          pkgsHostTarget.rustc
        ];
        substitutions = {
          inherit (pkgs.rust.envVars) rustTargetPlatformSpec setEnv;
        };
      }
      ./offline-maturin-build-hook.sh
  ) {};
  offlineMaturin = args: standardMaturin (args // {maturinHook = offlineMaturinHook;});
in (final: prev: {
  "2to3" = prev."2to3".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  # Needs manual merging
  #
  #                    "aardwolf"  = prev."aardwolf".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.rustc pkgs.cargo];});
  #
  #                    "aardwolf"  = prev."aardwolf".overridePythonAttrs (old: ((standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {maturinHook = null;}) old) //{
  #                        postPatch = let
  #                          cargo_lock = ./. + "/cargo.locks/${old.pname}/${old.version}.lock";
  #                        in
  #                        (old.postPatch or "") +
  #                        ''
  #                            echo "copying '${cargo_lock}' to Cargo.lock";
  #                            cp ${cargo_lock} Cargo.lock
  #                        '';
  #                });

  "about-time" = prev."about-time".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "acachecontrol" = prev."acachecontrol".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "adapt-parser" = prev."adapt-parser".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-fail "required('requirements.txt')" "['six']"
        '';
      }
  );

  "addonfactory-splunk-conf-parser-lib" =
    prev."addonfactory-splunk-conf-parser-lib".overridePythonAttrs
    (
      old:
        lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
          '';
        }
    );

  "aerich" = prev."aerich".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "aihelper" = prev."aihelper".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "aioeafm" = prev."aioeafm".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "aioextensions" = prev."aioextensions".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "aioify" = prev."aioify".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "aiolivisi" = prev."aiolivisi".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "aioserial" = prev."aioserial".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "album-runner" = prev."album-runner".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "alphatwirl" = prev."alphatwirl".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "anaconda-client" = prev."anaconda-client".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "anyjson" = prev."anyjson".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "apiritif" = prev."apiritif".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "app-store-scraper" = prev."app-store-scraper".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "apprise" = prev."apprise".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        buildInputs = (old.builtInputs or []) ++ [prev.babel];
      }
  );

  "arcane-core" = prev."arcane-core".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "arcane-datastore" = prev."arcane-datastore".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "arcane-firebase" = prev."arcane-firebase".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "arcane-requests" = prev."arcane-requests".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "arcgis2geojson" = prev."arcgis2geojson".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "argos-translate-files" = prev."argos-translate-files".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "argostranslate" = prev."argostranslate".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "arsenic" = prev."arsenic".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "artella-plugins-core" = prev."artella-plugins-core".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "artellapipe" = prev."artellapipe".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  # Needs manual merging
  #
  #                    "artellapipe-config"  = prev."artellapipe-config".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
  #            postPatch = ''
  #              substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
  #                --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
  #                --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
  #          });
  #
  #                    "artellapipe-config"  = prev."artellapipe-config".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;});

  "aryth" = prev."aryth".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "asgi-correlation-id" = prev."asgi-correlation-id".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "astral" = prev."astral".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "audeer" = prev."audeer".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "autocommand" = prev."autocommand".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace-quiet "requires-python" "license={ text = 'LGPLv3' } # requires-python"
        '';
      }
  );

  "azfs" = prev."azfs".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "azure-cosmosdb-nspkg" = prev."azure-cosmosdb-nspkg".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "b3j0f-annotation" = prev."b3j0f-annotation".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "backoff" = prev."backoff".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "backports-weakref" = prev."backports-weakref".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "bareasgi" = prev."bareasgi".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "baretypes" = prev."baretypes".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "bareutils" = prev."bareutils".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  # Needs manual merging
  #
  #                    "based58"  = prev."based58".overridePythonAttrs (old: ((standardMaturin {}) old) //{
  #                        postPatch = let
  #                          cargo_lock = ./. + "/cargo.locks/${old.pname}/${old.version}.lock";
  #                        in
  #                        (old.postPatch or "") +
  #                        ''
  #                            echo "copying '${cargo_lock}' to Cargo.lock";
  #                            cp ${cargo_lock} Cargo.lock
  #                        '';
  #                });
  #
  #                    "based58"  = prev."based58".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
  #  postPatch = old.postPatch or "" + ''
  #  touch LICENSE
  #  '';
  #}
  #);

  "beautifulsoup4" = prev."beautifulsoup4".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "beet" = prev."beet".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "behave" = prev."behave".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "benchling-api-client" = prev."benchling-api-client".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "benchling-sdk" = prev."benchling-sdk".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "bip32" = prev."bip32".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "birch" = prev."birch".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "blake3" = prev."blake3".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "blaze" = prev."blaze".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "blosc" = prev."blosc".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "blosc2" = prev."blosc2".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "bob" = prev."bob".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "booby" = prev."booby".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "brunns-row" = prev."brunns-row".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "cairocffi" = prev."cairocffi".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        buildInputs = old.buildInputs or [] ++ [final.pytest-runner];
        postInstall = "";
        patches = [];
      }
  );

  "calamus" = prev."calamus".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "cargo" = prev."cargo".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "casadi" = prev."casadi".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        preBuild = ''
          # go to the directory of setup.py
          # it get's lost in cmake.
          cd /build
          SETUP_PATH=`find . -name "setup.py" | sort | head -n 1`
          echo "SETUP_PATH: $SETUP_PATH"
          cd $(dirname $SETUP_PATH)
        '';
      }
  );

  "cdiserrors" = prev."cdiserrors".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "cdshealpix" = prev."cdshealpix".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "ceja" = prev."ceja".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "celery-singleton" = prev."celery-singleton".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "ckms" = prev."ckms".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "class-doc" = prev."class-doc".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "clean-text" = prev."clean-text".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "click-spinner" = prev."click-spinner".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "clingo" = prev."clingo".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "clip-anytorch" = prev."clip-anytorch".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "cloudflare-dyndns" = prev."cloudflare-dyndns".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "cloudshell-automation-api" = prev."cloudshell-automation-api".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "cloudshell-logging" = prev."cloudshell-logging".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "cloudshell-shell-core" = prev."cloudshell-shell-core".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "cloudshell-snmp" = prev."cloudshell-snmp".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "cloudsmith-cli" = prev."cloudsmith-cli".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          echo ${old.version} > VERSION
        '';
      }
  );

  "clvm-rs" = prev."clvm-rs".overridePythonAttrs (
    old: ((offlineMaturin {}) old)
  );

  "clvm-tools-rs" = prev."clvm-tools-rs".overridePythonAttrs (
    old: ((standardMaturin {}) old)
  );

  "clyent" = prev."clyent".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "cmdy" = prev."cmdy".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "codeowners" = prev."codeowners".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "cognite-sdk" = prev."cognite-sdk".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "cognite-sdk-experimental" = prev."cognite-sdk-experimental".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "concurrentloghandler" = prev."concurrentloghandler".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "correctionlib" = prev."correctionlib".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "cramjam" = prev."cramjam".overridePythonAttrs (
    old: ((offlineMaturin {}) old)
  );

  "crochet" = prev."crochet".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "crownstone-uart" = prev."crownstone-uart".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  # Needs manual merging
  #
  #                    "cryptg"  = prev."cryptg".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.rustc pkgs.cargo];});
  #
  #                    "cryptg"  = prev."cryptg".overridePythonAttrs (old: ((standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {maturinHook = null;}) old));

  "css-inline" = prev."css-inline".overridePythonAttrs (
    old:
      standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {
        furtherArgs = {
          cargoRoot = "bindings/python";
        };
      }
      old
  );

  "custom-inherit" = prev."custom-inherit".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "cvxopt" = prev."cvxopt".overridePythonAttrs (
    old: let
      blas = old.passthru.args.blas or pkgs.openblasCompat;
    in
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        buildInputs =
          old.buildInputs
          or []
          ++ [
            blas
            pkgs.suitesparse
          ];
      }
  );

  "dashscope" = prev."dashscope".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "databricks-api" = prev."databricks-api".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "databricks-automl-runtime" = prev."databricks-automl-runtime".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "databricks-feature-store" = prev."databricks-feature-store".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "databricks-vectorsearch" = prev."databricks-vectorsearch".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "dataengine" = prev."dataengine".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "dataflows-tabulator" = prev."dataflows-tabulator".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "datashape" = prev."datashape".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "dbt-adapters" = prev."dbt-adapters".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "dbt-core" = prev."dbt-core".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "dbt-extractor" = prev."dbt-extractor".overridePythonAttrs (
    old: (standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {
        furtherArgs = {
          cargoRoot = "";

          cargoDeps = (
            pkgs.rustPlatform.importCargoLock {
              lockFile = ./cargo.locks/dbt-extractor/0.5.1.lock;
              outputHashes = {
                "tree-sitter-jinja2-0.2.0" = "sha256-Hfw85IcxwqFDKjkUxU+Zd9vyL7gaE0u5TZGKol2I9qg=";
              };
            }
          );
        };
      }
      old)
  );

  "deptry" = prev."deptry".overridePythonAttrs (
    old: (standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {
        furtherArgs = {
          cargoRoot = "";

          cargoDeps = (
            pkgs.rustPlatform.importCargoLock {
              lockFile = ./cargo.locks/deptry/0.16.2.lock;
              outputHashes = {
                "ruff_python_ast-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
                "ruff_python_parser-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
                "ruff_python_trivia-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
                "ruff_source_file-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
                "ruff_text_size-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
              };
            }
          );
        };
      }
      old)
  );

  "deserialize" = prev."deserialize".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "dfa" = prev."dfa".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "dict-deep" = prev."dict-deep".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "dictionaryutils" = prev."dictionaryutils".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "diot" = prev."diot".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "django-crum" = prev."django-crum".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace 'setup.cfg' --replace-warn "setuptools-twine" ""
        '';
      }
  );

  "django-feed-reader" = prev."django-feed-reader".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch readme.md
        '';
      }
  );

  "django-guid" = prev."django-guid".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "django-jazzmin" = prev."django-jazzmin".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "django-split-settings" = prev."django-split-settings".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "django-utils-six" = prev."django-utils-six".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "documented" = prev."documented".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "docutils" = prev."docutils".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "docx2pdf" = prev."docx2pdf".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "doger" = prev."doger".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "dojo" = prev."dojo".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "domonic" = prev."domonic".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "dpt-file" = prev."dpt-file".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "dpt-runtime" = prev."dpt-runtime".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "drawnow" = prev."drawnow".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "drb" = prev."drb".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "drivelib" = prev."drivelib".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "dspy-ai" = prev."dspy-ai".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "eliot" = prev."eliot".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "eliot-tree" = prev."eliot-tree".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "embedly" = prev."embedly".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "empyrical" = prev."empyrical".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "etelemetry" = prev."etelemetry".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "eyed3" = prev."eyed3".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "eyes-universal" = prev."eyes-universal".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "fairlearn" = prev."fairlearn".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "fast-query-parsers" = prev."fast-query-parsers".overridePythonAttrs (
    old: ((standardMaturin {}) old)
  );

  "fastapi-cache2" = prev."fastapi-cache2".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "fastparquet" = prev."fastparquet".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.git];
      }
  );

  "flake8-breakpoint" = prev."flake8-breakpoint".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "flake8-markdown" = prev."flake8-markdown".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "flake8-pie" = prev."flake8-pie".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "flake8-return" = prev."flake8-return".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "flake8-use-pathlib" = prev."flake8-use-pathlib".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "flask" = prev."flask".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "flask-collect-invenio" = prev."flask-collect-invenio".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "pytest-runner>=3.0,<5" "pytest-runner>=3.0"
        '';
      }
  );

  "flask-dramatiq" = prev."flask-dramatiq".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "flask-limiter" = prev."flask-limiter".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "flox-core" = prev."flox-core".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "flutes" = prev."flutes".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "fondat" = prev."fondat".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "galaxy-fds-sdk" = prev."galaxy-fds-sdk".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "galaxy-util" = prev."galaxy-util".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "geojson-rewind" = prev."geojson-rewind".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "giant-mixins" = prev."giant-mixins".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "gilknocker" = prev."gilknocker".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "gino" = prev."gino".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "glean-sdk" = prev."glean-sdk".overridePythonAttrs (
    old: ((offlineMaturin {}) old)
  );

  "gmplot" = prev."gmplot".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "grabbit" = prev."grabbit".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "graia-application-mirai" = prev."graia-application-mirai".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "graia-broadcast" = prev."graia-broadcast".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "graphlib-backport" = prev."graphlib-backport".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "grimp" = prev."grimp".overridePythonAttrs (
    old:
      standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {
        furtherArgs = {
          cargoRoot = "rust";
        };
      }
      old
  );

  # Needs manual merging
  #
  #                    "h3"  = prev."h3".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; });
  #
  #                    "h3"  = prev."h3".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
  #  # have to throw away the old preBuild
  #  preBuild = ''
  #    if [ -f h3/h3.py ]; then
  #      substituteInPlace h3/h3.py \
  #        --replace "'{}/{}'.format(_dirname, libh3_path)" '"${pkgs.h3}/lib/libh3${sharedLibExt}"'
  #        fi
  #  '';
  #}
  #);

  "h3ronpy" = prev."h3ronpy".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "hdfdict" = prev."hdfdict".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "hdfs3" = prev."hdfs3".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "hieroglyph" = prev."hieroglyph".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "hive-metastore-client" = prev."hive-metastore-client".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "html2image" = prev."html2image".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "http3" = prev."http3".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "httprunner" = prev."httprunner".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "hwi" = prev."hwi".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "idds-common" = prev."idds-common".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "imgsize" = prev."imgsize".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "impyla" = prev."impyla".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "incomfort-client" = prev."incomfort-client".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "intake-geopandas" = prev."intake-geopandas".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "intake-parquet" = prev."intake-parquet".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "interpolation" = prev."interpolation".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "intype" = prev."intype".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "iterwrapper" = prev."iterwrapper".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch readme.md
        '';
      }
  );

  "itly-sdk" = prev."itly-sdk".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "java-manifest" = prev."java-manifest".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "ject" = prev."ject".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "jellyfish" = prev."jellyfish".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "jetblack-asgi-typing" = prev."jetblack-asgi-typing".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "jiter" = prev."jiter".overridePythonAttrs (
    old: ((offlineMaturin {}) old)
  );

  "kenlm" = prev."kenlm".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "kurbopy" = prev."kurbopy".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "levenshtein" = prev."levenshtein".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        preBuild = ''
          cd /build/Levenshtein-${old.version}
          find .
        '';
      }
  );

  "libhoney" = prev."libhoney".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "librespot" = prev."librespot".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "libthumbor" = prev."libthumbor".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "license-expression" = prev."license-expression".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontConfigure = true;}
  );

  "liftover" = prev."liftover".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        buildInputs = (old.buildInputs or {}) ++ [pkgs.zlib];
      }
  );

  "ligotimegps" = prev."ligotimegps".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "limits" = prev."limits".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "link-feature" = prev."link-feature".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "lintrunner" = prev."lintrunner".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "liquidpy" = prev."liquidpy".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "logdna" = prev."logdna".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "loggable-jdv" = prev."loggable-jdv".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "lvis" = prev."lvis".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "lxml" = prev."lxml".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        # force cython regeneration
        buildInputs = old.buildInputs or [] ++ [final.cython_0];
        postPatch = ''
          find -name '*.c' | xargs rm
        '';
      }
  );

  "lzallright" = prev."lzallright".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "mabwiser" = prev."mabwiser".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "mailer" = prev."mailer".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "mantichora" = prev."mantichora".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "matchpy" = prev."matchpy".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "matplotlib-scalebar" = prev."matplotlib-scalebar".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  # Needs manual merging
  #
  #                    "maturin"  = prev."maturin".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.rustc pkgs.cargo];});
  #
  #                    "maturin"  = prev."maturin".overridePythonAttrs (old: ((standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {maturinHook = null;}) old));

  "memory-tempfile" = prev."memory-tempfile".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "messages" = prev."messages".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "mill-local" = prev."mill-local".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "minify-html" = prev."minify-html".overridePythonAttrs (
    old: ((offlineMaturin {}) old)
  );

  "minijinja" = prev."minijinja".overridePythonAttrs (
    old: ((offlineMaturin {}) old)
  );

  "mitmproxy-wireguard" = prev."mitmproxy-wireguard".overridePythonAttrs (
    old: ((standardMaturin {}) old)
  );

  "mixins" = prev."mixins".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "mocpy" = prev."mocpy".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "model-index" = prev."model-index".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "modelcards" = prev."modelcards".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "module-wrapper" = prev."module-wrapper".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "monai" = prev."monai".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "msgpack" = prev."msgpack".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  # Needs manual merging
  #
  #                    "multicoretsne"  = prev."multicoretsne".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
  #  postPatch = ''
  #    substituteInPlace setup.py --replace-fail 'self.cmake_args or "--"' 'self.cmake_args or ""'
  #
  #  '';
  #}
  #);
  #
  #                    "multicoretsne"  = prev."multicoretsne".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; });

  "multiprocess" = prev."multiprocess".override {preferWheel = true;};

  "muscima" = prev."muscima".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "mwdblib" = prev."mwdblib".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "nats-python" = prev."nats-python".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "nbtlib" = prev."nbtlib".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "netifaces2" = prev."netifaces2".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "netmiko" = prev."netmiko".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "networkit" = prev."networkit".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "nevow" = prev."nevow".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "nichelper" = prev."nichelper".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "nidaqmx" = prev."nidaqmx".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "nilspodlib" = prev."nilspodlib".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "nornir" = prev."nornir".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "nornir-napalm" = prev."nornir-napalm".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "nornir-netmiko" = prev."nornir-netmiko".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "nornir-utils" = prev."nornir-utils".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "notmuch" = prev."notmuch".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "nutils-poly" = prev."nutils-poly".overridePythonAttrs (
    old: ((standardMaturin {}) old)
  );

  "nutter" = prev."nutter".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "nvidia-ml-py3" = prev."nvidia-ml-py3".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "nvsmi" = prev."nvsmi".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "ob" = prev."ob".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "ocpp" = prev."ocpp".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "odo" = prev."odo".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "onepasswordconnectsdk" = prev."onepasswordconnectsdk".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "ontospy" = prev."ontospy".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  # Needs manual merging
  #
  #                    "opencv-contrib-python-headless"  = prev."opencv-contrib-python-headless".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; });
  #
  #                    "opencv-contrib-python-headless"  = prev."opencv-contrib-python-headless".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
  #  postPatch = ''
  #    sed -i pyproject.toml -e 's/numpy==[0-9]\+\.[0-9]\+\.[0-9]\+;/numpy;/g'
  #    # somehow the type information doesn't get build
  #    substituteInPlace setup.py --replace-fail '[ r"python/cv2/py.typed" ] if sys.version_info >= (3, 6) else []' "[]" \
  #    --replace-fail 'rearrange_cmake_output_data["cv2.typing"] = ["python/cv2" + r"/typing/.*\.py"]' "pass"
  #  '';
  #}
  #);

  "opencv-python" = prev."opencv-python".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          sed -i pyproject.toml -e 's/numpy==[0-9]\+\.[0-9]\+\.[0-9]\+;/numpy;/g'
          # somehow the type information doesn't get build
          substituteInPlace setup.py --replace-fail '[ r"python/cv2/py.typed" ] if sys.version_info >= (3, 6) else []' "[]" \
          --replace-fail 'rearrange_cmake_output_data["cv2.typing"] = ["python/cv2" + r"/typing/.*\.py"]' "pass"
        '';
      }
  );

  "openevsewifi" = prev."openevsewifi".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "opsdroid-get-image-size" = prev."opsdroid-get-image-size".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "opt-einsum" = prev."opt-einsum".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "optree" = prev."optree".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "orator" = prev."orator".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "oslash" = prev."oslash".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "outcome-utils" = prev."outcome-utils".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "ovos-config" = prev."ovos-config".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          mkdir requirements
          touch requirements/requirements.txt
          touch requirements/extras.txt
        '';
      }
  );

  "pandahouse" = prev."pandahouse".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "pandas" = prev."pandas".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch =
          (old.postPatch or "")
          + ''
            if [ -f versioneer.py ]; then
              substituteInPlace versioneer.py \
                --replace-quiet "SafeConfigParser" "ConfigParser" \
                --replace-quiet "readfp" "read_file"
            fi
          '';
      }
  );

  "pandas-datareader" = prev."pandas-datareader".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "pastel" = prev."pastel".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "patch" = prev."patch".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        unpackPhase = ''
          cd /build
          mkdir ${old.pname}-${old.version}
          cd ${old.pname}-${old.version}
          unzip ${old.src}
        '';
      }
  );

  "patchify" = prev."patchify".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pathmagic" = prev."pathmagic".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pathpy" = prev."pathpy".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch HISTORY.rst
        '';
      }
  );

  "pdfx" = prev."pdfx".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pdoc-pyo3-sample-library" = prev."pdoc-pyo3-sample-library".overridePythonAttrs (
    old: ((standardMaturin {}) old)
  );

  "periodiq" = prev."periodiq".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pipda" = prev."pipda".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "piq" = prev."piq".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pixivpy" = prev."pixivpy".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pm4py" = prev."pm4py".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "poetry-semver" = prev."poetry-semver".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "poetry-version" = prev."poetry-version".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pokrok" = prev."pokrok".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "poppy-core" = prev."poppy-core".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "pprofile" = prev."pprofile".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "progressbar-ipython" = prev."progressbar-ipython".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace progressbar/__init__.py \
            --replace-quiet "from compat import *" "from .compat import *" \
            --replace-quiet "from widgets import *" "from .widgets import *"
        '';
      }
  );

  "prompter" = prev."prompter".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "publicsuffix2" = prev."publicsuffix2".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {buildInputs = [prev.requests];}
  );

  "py-aiger" = prev."py-aiger".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "py-aiger-bv" = prev."py-aiger-bv".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pyannote-core" = prev."pyannote-core".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "pyannote-metrics" = prev."pyannote-metrics".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "pyap" = prev."pyap".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pyarr" = prev."pyarr".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pyarrow" = prev."pyarrow".override {preferWheel = true;};

  "pyauto-core" = prev."pyauto-core".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "pyauto-util" = prev."pyauto-util".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "pycallgraph" = prev."pycallgraph".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "pycddl" = prev."pycddl".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "pycrdt" = prev."pycrdt".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "pydata-google-auth" = prev."pydata-google-auth".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "pydicom-seg" = prev."pydicom-seg".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pydot2" = prev."pydot2".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "pydriller" = prev."pydriller".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pyfolio" = prev."pyfolio".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "pyfunctional" = prev."pyfunctional".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pyglove" = prev."pyglove".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pyhepmc" = prev."pyhepmc".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "pyknp" = prev."pyknp".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pylibjpeg-openjpeg" = prev."pylibjpeg-openjpeg".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "pylogbeat" = prev."pylogbeat".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace 'setup.py' --replace-warn "rmtree(directory, ignore_errors=True)" "pass"
        '';
      }
  );

  "pymannkendall" = prev."pymannkendall".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "pymarshaler" = prev."pymarshaler".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pymel" = prev."pymel".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pymiscutils" = prev."pymiscutils".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pynetgear" = prev."pynetgear".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pynng" = prev."pynng".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "pynvml" = prev."pynvml".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "pyparam" = prev."pyparam".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pypeln" = prev."pypeln".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pyppeteer2" = prev."pyppeteer2".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pyrad" = prev."pyrad".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pyrevm" = prev."pyrevm".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "pysam" = prev."pysam".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        buildInputs =
          old.buildInputs
          or []
          ++ [
            pkgs.zlib
            pkgs.bzip2
            pkgs.xz
            pkgs.curl
          ];
      }
  );

  "pysnmp" = prev."pysnmp".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py \
           --replace-fail "observed_version = [int(x) for x in setuptools.__version__.split('.')]" "observed_version = [70,]"
        ''; # anything over 36.2.0 should be ok.
      }
  );

  "pysnow" = prev."pysnow".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pysnyk" = prev."pysnyk".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pysubtypes" = prev."pysubtypes".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pytest-docker-tools" = prev."pytest-docker-tools".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pytest-golden" = prev."pytest-golden".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pytest-mockservers" = prev."pytest-mockservers".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pytest-reraise" = prev."pytest-reraise".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pytest-spec" = prev."pytest-spec".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pytextspan" = prev."pytextspan".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "python-creole" = prev."python-creole".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "python-graph-core" = prev."python-graph-core".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "python-jsonrpc-server" = prev."python-jsonrpc-server".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "python-language-server" = prev."python-language-server".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "python-magic" = prev."python-magic".overridePythonAttrs (
    old: let
      sharedLibExt = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
      libPath = "${lib.getLib pkgs.file}/lib/libmagic${sharedLibExt}";
      fixupScriptText = ''
        if [ -f magic/loader.py ]; then
          substituteInPlace magic/loader.py \
            --replace "find_library('magic')" "'${libPath}'"
        else
          substituteInPlace magic.py \
            --replace-fail "ctypes.util.find_library('magic')" "'${libPath}'" \
            --replace-fail "ctypes.util.find_library('magic1')" "'${libPath}'"
        fi
      '';
      isWheel = old.src.isWheel or false;
    in
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = lib.optionalString (!isWheel) fixupScriptText;
        postFixup = lib.optionalString isWheel ''
          cd $out/${final.python.sitePackages}
          ${fixupScriptText}
        '';
        pythonImportsCheck = old.pythonImportsCheck or [] ++ ["magic"];
      }
  );

  "python-mimeparse" = prev."python-mimeparse".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "python-picnic-api" = prev."python-picnic-api".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "python-pushover" = prev."python-pushover".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "python-simpleconf" = prev."python-simpleconf".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "python-tado" = prev."python-tado".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "python-tlsh" = prev."python-tlsh".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "pytm" = prev."pytm".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pytorch-tabnet" = prev."pytorch-tabnet".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "pyvcf" = prev."pyvcf".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "pyvin" = prev."pyvin".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "pywinpty" = prev."pywinpty".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "pyxirr" = prev."pyxirr".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "pyzoom" = prev."pyzoom".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "qcs-api-client" = prev."qcs-api-client".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "qdldl" = prev."qdldl".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "qt5reactor" = prev."qt5reactor".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "qtoml" = prev."qtoml".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "quil" = prev."quil".overridePythonAttrs (
    old: ((offlineMaturin {}) old)
  );

  "quimb" = prev."quimb".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "quinn" = prev."quinn".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "readmdict" = prev."readmdict".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "reference-handler" = prev."reference-handler".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "regress" = prev."regress".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "regressors" = prev."regressors".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "replit" = prev."replit".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "resend" = prev."resend".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "rfc6266" = prev."rfc6266".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "rfc7464" = prev."rfc7464".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "rhino3dm" = prev."rhino3dm".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "roboflow" = prev."roboflow".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "robotframework-seleniumtestability" =
    prev."robotframework-seleniumtestability".overridePythonAttrs
    (
      old:
        lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
        }
    );

  "royalnet" = prev."royalnet".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "rqdatac" = prev."rqdatac".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "runipy" = prev."runipy".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  # Needs manual merging
  #
  #                    "rustworkx"  = prev."rustworkx".overridePythonAttrs (old: ((standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {maturinHook = null;}) old));
  #
  #                    "rustworkx"  = prev."rustworkx".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.rustc pkgs.cargo];});

  "scikit-base" = prev."scikit-base".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "scikit-image" = prev."scikit-image".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          patchShebangs skimage/_build_utils/{version,cythoner}.py
        '';
      }
  );

  "scikit-surgeryarucotracker" = prev."scikit-surgeryarucotracker".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "scikit-surgeryimage" = prev."scikit-surgeryimage".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "scim2-filter-parser" = prev."scim2-filter-parser".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "scrapelib" = prev."scrapelib".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  # Needs manual merging
  #
  #                    "scs"  = prev."scs".overridePythonAttrs (old: let
  #  blas = old.passthru.args.blas or pkgs.openblasCompat;
  #in lib.optionalAttrs (!(old.src.isWheel or false)) {
  #  buildInputs = old.buildInputs or [] ++ [blas pkgs.lapack];
  #}
  #);
  #
  #                    "scs"  = prev."scs".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; });

  "setuptools-scm-git-archive" = prev."setuptools-scm-git-archive".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "setuptools-scm<8" "setuptools-scm"
        '';
      }
  );

  "sevenbridges-python" = prev."sevenbridges-python".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "sharkiq" = prev."sharkiq".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "simplug" = prev."simplug".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "siphon" = prev."siphon".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  # Needs manual merging
  #
  #                    "skytemple-rust"  = prev."skytemple-rust".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.rustc pkgs.cargo];});
  #
  #                    "skytemple-rust"  = prev."skytemple-rust".overridePythonAttrs (old: ((standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {maturinHook = null;}) old));

  "solders" = prev."solders".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "solidpython" = prev."solidpython".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  # Needs manual merging
  #
  #                    "spacy-alignments"  = prev."spacy-alignments".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.rustc pkgs.cargo];});
  #
  #                    "spacy-alignments"  = prev."spacy-alignments".overridePythonAttrs (old: ((standardMaturin lib.optionalAttrs (!(old.src.isWheel or false)) {maturinHook = null;}) old));

  # Needs manual merging
  #
  #                    "sparse-dot-topn"  = prev."sparse-dot-topn".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; });
  #
  #                    "sparse-dot-topn"  = prev."sparse-dot-topn".overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
  #                CMAKE_PREFIX_PATH = "${prev.nanobind}/lib/python${lib.versions.majorMinor final.python.version}/site-packages/nanobind/cmake";
  #
  #        });

  "spglib" = prev."spglib".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "sphinx-data-viewer" = prev."sphinx-data-viewer".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "sphinx-markdown-parser" = prev."sphinx-markdown-parser".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "spylls" = prev."spylls".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "starlette-prometheus" = prev."starlette-prometheus".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "stdlib-list" = prev."stdlib-list".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "stegano" = prev."stegano".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "stomp-py" = prev."stomp-py".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "streamerate" = prev."streamerate".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "strenum" = prev."strenum".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "strip-ansi" = prev."strip-ansi".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "suitcase-utils" = prev."suitcase-utils".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "synologydsm-api" = prev."synologydsm-api".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "tabulator" = prev."tabulator".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "tartiflette" = prev."tartiflette".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "taskipy" = prev."taskipy".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "telfhash" = prev."telfhash".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "tempita" = prev."tempita".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "tendril-utils-core" = prev."tendril-utils-core".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "tendril-utils-yaml" = prev."tendril-utils-yaml".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "texting" = prev."texting".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "theano-pymc" = prev."theano-pymc".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "timing-asgi" = prev."timing-asgi".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "tinydb-serialization" = prev."tinydb-serialization".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "tlparse" = prev."tlparse".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "tomlkit" = prev."tomlkit".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "topgrade" = prev."topgrade".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "torch-fidelity" = prev."torch-fidelity".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "torchao" = prev."torchao".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "tpdcc-config" = prev."tpdcc-config".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "tpdcc-dccs-maya" = prev."tpdcc-dccs-maya".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "tpdcc-libs-plugin" = prev."tpdcc-libs-plugin".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "tpdcc-libs-qt" = prev."tpdcc-libs-qt".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "tpdcc-libs-resources" = prev."tpdcc-libs-resources".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "trading-calendars" = prev."trading-calendars".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "traits" = prev."traits".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
      }
  );

  "trame-client" = prev."trame-client".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "translatehtml" = prev."translatehtml".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "trio-chrome-devtools-protocol" = prev."trio-chrome-devtools-protocol".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "twitchio" = prev."twitchio".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "typer" = prev."typer".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "types-pyopenssl" = prev."types-pyopenssl".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "types-pyside2" = prev."types-pyside2".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "types-setuptools" = prev."types-setuptools".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "tzfpy" = prev."tzfpy".overridePythonAttrs (
    old: (standardMaturin {}) old
  );

  "ultimate-hosts-blacklist-helpers" = prev."ultimate-hosts-blacklist-helpers".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "ultralytics-thop" = prev."ultralytics-thop".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "unicorn" = prev."unicorn".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        # from nixpkgs.
        prePatch = ''
          ln -s ${pkgs.unicorn-emu}/lib/libunicorn.* prebuilt/
        '';
      }
  );

  "unimatrix" = prev."unimatrix".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "upnpclient" = prev."upnpclient".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "uuid-utils" = prev."uuid-utils".overridePythonAttrs (
    old: ((standardMaturin {}) old)
  );

  "valley" = prev."valley".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "varname" = prev."varname".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "vbuild" = prev."vbuild".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "vcard" = prev."vcard".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "vega" = prev."vega".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "veho" = prev."veho".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "venv-pack" = prev."venv-pack".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "vsts" = prev."vsts".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {meta.priority = 1;}
  );

  "warrant-lite" = prev."warrant-lite".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "webdrivermanager" = prev."webdrivermanager".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      }
  );

  "xatlas" = prev."xatlas".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "xbbg" = prev."xbbg".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "xgboost" = prev."xgboost".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "xpath-expressions" = prev."xpath-expressions".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
      }
  );

  "yamlconf" = prev."yamlconf".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "yolov5" = prev."yolov5".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "your" = prev."your".overridePythonAttrs (
    old:
      lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          touch requirements.txt
        '';
      }
  );

  "z3-solver" = prev."z3-solver".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );

  "zxing-cpp" = prev."zxing-cpp".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) {dontUseCmakeConfigure = true;}
  );
})
