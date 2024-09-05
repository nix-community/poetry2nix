{ pkgs, lib }:
let
  standardMaturin =
    {
      furtherArgs ? { },
      maturinHook ? pkgs.rustPlatform.maturinBuildHook,
    }:
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) (
      {
        cargoDeps = pkgs.rustPlatform.importCargoLock {
          lockFile = ./. + "/cargo.locks/${old.pname}/${old.version}.lock";
        };
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ [
            pkgs.rustPlatform.cargoSetupHook
            maturinHook
          ]
          ++ (furtherArgs.nativeBuildInputs or [ ]);
      }
      # furtherargs without nativeBuildInputs
      // lib.attrsets.filterAttrs (name: _value: name != "nativeBuildInputs") furtherArgs
    );
  offlineMaturinHook = pkgs.callPackage (
    { pkgsHostTarget }:
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
    } ./offline-maturin-build-hook.sh
  ) { };
  offlineMaturin = args: standardMaturin (args // { maturinHook = offlineMaturinHook; });
in
final: prev: {
  "2to3" = prev."2to3".overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  aardwolf = prev.aardwolf.overridePythonAttrs (
    old:
    standardMaturin {
      maturinHook = null;

      furtherArgs = {
        postPatch =
          let
            cargo_lock = ./. + "/cargo.locks/${old.pname}/${old.version}.lock";
          in
          (old.postPatch or "")
          + ''
            echo "copying '${cargo_lock}' to Cargo.lock";
            cp ${cargo_lock} Cargo.lock
          '';
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          pkgs.rustc
          pkgs.cargo
        ];
      };
    } old
  );

  about-time = prev.about-time.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  acachecontrol = prev.acachecontrol.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  adapt-parser = prev.adapt-parser.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-fail "required('requirements.txt')" "['six']"
        '';
    }
  );

  addonfactory-splunk-conf-parser-lib = prev.addonfactory-splunk-conf-parser-lib.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  aerich = prev.aerich.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  aihelper = prev.aihelper.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  aioeafm = prev.aioeafm.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  aioextensions = prev.aioextensions.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  aioify = prev.aioify.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  aiolivisi = prev.aiolivisi.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  aioserial = prev.aioserial.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  album-runner = prev.album-runner.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  alphatwirl = prev.alphatwirl.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  anaconda-client = prev.anaconda-client.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  anndata = prev.anndata.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  anybadge = prev.anybadge.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { TRAVIS_TAG = "v${old.version}"; }
  );

  anyjson = prev.anyjson.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  apiritif = prev.apiritif.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  app-store-scraper = prev.app-store-scraper.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  apprise = prev.apprise.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      buildInputs = (old.builtInputs or [ ]) ++ [ prev.babel ];
    }
  );

  arcane-core = prev.arcane-core.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  arcane-datastore = prev.arcane-datastore.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  arcane-firebase = prev.arcane-firebase.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  arcane-requests = prev.arcane-requests.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  arcgis2geojson = prev.arcgis2geojson.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  argos-translate-files = prev.argos-translate-files.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  argostranslate = prev.argostranslate.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  arsenic = prev.arsenic.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  artella-plugins-core = prev.artella-plugins-core.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  artellapipe = prev.artellapipe.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  artellapipe-config = prev.artellapipe-config.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      meta.priority = 1;

      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
           --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
    }
  );

  aryth = prev.aryth.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  asgi-correlation-id = prev.asgi-correlation-id.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  astral = prev.astral.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  atari-py = prev.atari-py.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      dontUseCmakeConfigure = true;
      buildInputs = [ pkgs.zlib ];
    }
  );

  audeer = prev.audeer.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  autocommand = prev.autocommand.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f pyproject.toml ]; then
            substituteInPlace pyproject.toml --replace-quiet "requires-python" "license={ text = 'LGPLv3' } # requires-python"
          fi
        '';
    }
  );

  autoray = prev.autoray.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  azfs = prev.azfs.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  azure-cosmosdb-nspkg = prev.azure-cosmosdb-nspkg.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  b3j0f-annotation = prev.b3j0f-annotation.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  b3j0f-aop = prev.b3j0f-aop.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  babelfish = prev.babelfish.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch HISTORY.rst
        '';
    }
  );

  babelfont = prev.babelfont.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch HISTORY.rst
        '';
    }
  );

  backoff = prev.backoff.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  backports-weakref = prev.backports-weakref.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  bareasgi = prev.bareasgi.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  baretypes = prev.baretypes.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  bareutils = prev.bareutils.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f "pyproject.toml" ]; then
            substituteInPlace pyproject.toml --replace-quiet "poetry.masonry.api" "poetry.core.masonry.api"
          fi
          touch requirements.txt
        '';
    }
  );

  based58 = prev.based58.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = {
        postPatch =
          let
            cargo_lock = ./. + "/cargo.locks/${old.pname}/${old.version}.lock";
          in
          old.postPatch or ""
            + ''
              touch LICENSE
              cp ${cargo_lock} Cargo.lock
            '';
      };
    })
      old
  );

  batchglm = prev.batchglm.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  beautifulsoup4 = prev.beautifulsoup4.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  beet = prev.beet.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  behave = prev.behave.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  benchling-api-client = prev.benchling-api-client.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  benchling-sdk = prev.benchling-sdk.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  bip32 = prev.bip32.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  birch = prev.birch.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  blake3 = prev.blake3.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  blaze = prev.blaze.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  blosc = prev.blosc.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  blosc2 = prev.blosc2.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  bluesky-live = prev.bluesky-live.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  bob = prev.bob.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  bokeh = prev.bokeh.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  booby = prev.booby.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  brunns-row = prev.brunns-row.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  bx-py-utils = prev.bx-py-utils.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  cairocffi = prev.cairocffi.overridePythonAttrs (
    old: # we have to keep our own patchset to support multiple cairocffi versions
    # independent of the nixpkgs version
    let
      patch_path =
        if (lib.versionAtLeast old.version "1.7") then
          ./patches/cairocffi/1.7.0
        else
          (
            if (lib.versionAtLeast old.version "1.1.0") then
              ./patches/cairocffi/1.6.2
            else
              (
                if (lib.versionAtLeast old.version "1.0.0") then
                  ./patches/cairocffi/1.0.0
                else
                  patches/cairocffi/0.9
              )
          );
      patches =
        with pkgs;
        [
          # OSError: dlopen() failed to load a library: gdk-pixbuf-2.0 / gdk-pixbuf-2.0-0
          (substituteAll {
            src = patch_path + "/dlopen-paths.patch";
            ext = stdenv.hostPlatform.extensions.sharedLibrary;
            cairo = cairo.out;
            glib = glib.out;
            gdk_pixbuf = gdk-pixbuf.out;
          })
        ]
        ++ (lib.lists.optional (lib.versionAtLeast old.version "1.1.0") (
          patch_path + "/fix_test_scaled_font.patch"
        ));
    in
    {
      buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
      postInstall = lib.optionalString (old.src.isWheel or false) ''
        pushd "$out/${final.python.sitePackages}"
        for patch in ${lib.concatMapStringsSep " " (p: "${p}") patches}; do
          patch -p1 < "$patch"
        done
        popd
      '';
    }
    // lib.optionalAttrs (!(old.src.isWheel or false)) { inherit patches; }
  );

  calamus = prev.calamus.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  canmatrix = prev.canmatrix.overridePythonAttrs (
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

  cargo = prev.cargo.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  casadi = prev.casadi.overridePythonAttrs (
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

  cbpro = prev.cbpro.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch README.md
        '';
    }
  );

  cdiserrors = prev.cdiserrors.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  cdshealpix = prev.cdshealpix.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  ceja = prev.ceja.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  celery-singleton = prev.celery-singleton.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  char = prev.char.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py \
            --replace-fail 'use_pyscaffold=True' 'use_pyscaffold=True, version="${old.version}"'
        '';
    }
  );

  chrome-devtools-protocol = prev.chrome-devtools-protocol.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  ckms = prev.ckms.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  class-doc = prev.class-doc.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  clean-text = prev.clean-text.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  click-datetime = prev.click-datetime.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch README.md
        '';
    }
  );

  click-spinner = prev.click-spinner.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        ''
        + (lib.optionalString (lib.versionOlder old.version "0.1.5") ''
          touch README.md
        '');
    }
  );

  clingo = prev.clingo.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  clip-anytorch = prev.clip-anytorch.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  cloudflare-dyndns = prev.cloudflare-dyndns.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  cloudshell-automation-api = prev.cloudshell-automation-api.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  cloudshell-core = prev.cloudshell-core.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  cloudshell-logging = prev.cloudshell-logging.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  cloudshell-shell-core = prev.cloudshell-shell-core.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  cloudshell-snmp = prev.cloudshell-snmp.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  cloudsmith-cli = prev.cloudsmith-cli.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          echo ${old.version} > VERSION
        '';
    }
  );

  clvm-rs = prev.clvm-rs.overridePythonAttrs (old: ((offlineMaturin { furtherArgs = { }; }) old));

  clvm-tools-rs = prev.clvm-tools-rs.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  clyent = prev.clyent.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  cmdy = prev.cmdy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  codeowners = prev.codeowners.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  cognite-logger = prev.cognite-logger.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  cognite-sdk = prev.cognite-sdk.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  cognite-sdk-experimental = prev.cognite-sdk-experimental.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  concurrentloghandler = prev.concurrentloghandler.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  correctionlib = prev.correctionlib.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  cramjam = prev.cramjam.overridePythonAttrs (
    old: (offlineMaturin { furtherArgs = { }; } old)

  );

  crochet = prev.crochet.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  crownstone-core = prev.crownstone-core.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  crownstone-uart = prev.crownstone-uart.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  cryptg = prev.cryptg.overridePythonAttrs (
    old:
    (
      (standardMaturin {
        maturinHook = null;
        furtherArgs = {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pkgs.rustc
            pkgs.cargo
          ];
        };
      })
      old
    )
  );

  css-inline = prev.css-inline.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = lib.optionalAttrs (lib.versionOlder old.version "0.14.0") {
        cargoRoot = "bindings/python";
      };
    } old)
  );

  custom-inherit = prev.custom-inherit.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  cvxopt = prev.cvxopt.overridePythonAttrs (
    old:
    let
      blas = old.passthru.args.blas or pkgs.openblasCompat;
    in
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      buildInputs = old.buildInputs or [ ] ++ [
        blas
        pkgs.suitesparse
      ];

      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  dashscope = prev.dashscope.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  databricks-api = prev.databricks-api.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  databricks-automl-runtime = prev.databricks-automl-runtime.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  databricks-feature-store = prev.databricks-feature-store.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  databricks-sdk = prev.databricks-sdk.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  databricks-vectorsearch = prev.databricks-vectorsearch.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  databroker = prev.databroker.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
              touch requirements.txt
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  dataengine = prev.dataengine.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  dataflows-tabulator = prev.dataflows-tabulator.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  datafusion = prev.datafusion.overridePythonAttrs (
    old:
    standardMaturin {
      furtherArgs = {
        nativeBuildInputs = [ pkgs.protobuf_26 ];
      };
    } old
  );

  datashape = prev.datashape.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  datasketches = prev.datasketches.override { preferWheel = true; } # or teach it to download the cpp sources and place them in the right place
  ;

  dbt-adapters = prev.dbt-adapters.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  dbt-core = prev.dbt-core.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  dbt-extractor = prev.dbt-extractor.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = {
        cargoRoot = "";

        cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = ./cargo.locks/dbt-extractor/${old.version}.lock;

            outputHashes =
              let
                lookup = {
                  "0.4.1" = {
                    "tree-sitter-jinja2-0.1.0" = "sha256-lzA2iq4AK0iNwkLvbIt7Jm5WGFbMPFDi6i4AFDm0FOU=";
                  };
                  "0.5.1" = {
                    "tree-sitter-jinja2-0.2.0" = "sha256-Hfw85IcxwqFDKjkUxU+Zd9vyL7gaE0u5TZGKol2I9qg=";
                  };
                };
              in
              lookup.${old.version} or { };
          };
      };
    } old)
  );

  deptry = prev.deptry.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = {
        cargoRoot = "";

        cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = ./cargo.locks/deptry/${old.version}.lock;

            outputHashes =
              let
                lookup = {
                  "0.15.0" = {
                    "ruff_python_ast-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_python_parser-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_python_trivia-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_source_file-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_text_size-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                  };
                  "0.16.0" = {
                    "ruff_python_ast-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_python_parser-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_python_trivia-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_source_file-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_text_size-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                  };
                  "0.16.1" = {
                    "ruff_python_ast-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_python_parser-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_python_trivia-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_source_file-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                    "ruff_text_size-0.0.0" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
                  };
                  "0.16.2" = {
                    "ruff_python_ast-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
                    "ruff_python_parser-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
                    "ruff_python_trivia-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
                    "ruff_source_file-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
                    "ruff_text_size-0.0.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
                  };
                };
              in
              lookup.${old.version} or { };
          };
      };
    } old)
  );

  deserialize = prev.deserialize.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  dfa = prev.dfa.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  dict-deep = prev.dict-deep.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  dictionaryutils = prev.dictionaryutils.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  diffxpy = prev.diffxpy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  diot = prev.diot.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  django-crum = prev.django-crum.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace 'setup.cfg' --replace-warn "setuptools-twine" ""
        '';
    }
  );

  django-feed-reader = prev.django-feed-reader.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch readme.md
        '';
    }
  );

  django-guid = prev.django-guid.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  django-jazzmin = prev.django-jazzmin.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  django-rest-passwordreset = prev.django-rest-passwordreset.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { PACKAGE_VERSION = old.version; }
  );

  django-split-settings = prev.django-split-settings.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  django-utils-six = prev.django-utils-six.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  dnspython = prev.dnspython.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  documented = prev.documented.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  docutils = prev.docutils.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  docx2pdf = prev.docx2pdf.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  doger = prev.doger.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  dojo = prev.dojo.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  domonic = prev.domonic.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  dpt-file = prev.dpt-file.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  dpt-runtime = prev.dpt-runtime.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  drawnow = prev.drawnow.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  drb = prev.drb.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  drivelib = prev.drivelib.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  dspy-ai = prev.dspy-ai.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  eliot = prev.eliot.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  eliot-tree = prev.eliot-tree.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  embedly = prev.embedly.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
    }
  );

  empyrical = prev.empyrical.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  esda = prev.esda.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch README.md
        '';
    }
  );

  etelemetry = prev.etelemetry.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  eyed3 = prev.eyed3.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  eyes-universal = prev.eyes-universal.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  fairlearn = prev.fairlearn.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  fast-query-parsers = prev.fast-query-parsers.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  fastapi-cache2 = prev.fastapi-cache2.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  flake8-breakpoint = prev.flake8-breakpoint.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  flake8-markdown = prev.flake8-markdown.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  flake8-pie = prev.flake8-pie.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  flake8-return = prev.flake8-return.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  flake8-use-pathlib = prev.flake8-use-pathlib.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  flask = prev.flask.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  flask-collect-invenio = prev.flask-collect-invenio.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-quiet "pytest-runner>=3.0,<5" "pytest-runner>=3.0"
        '';
    }
  );

  flask-dramatiq = prev.flask-dramatiq.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  flask-limiter = prev.flask-limiter.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  flox-core = prev.flox-core.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  flutes = prev.flutes.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  flynt = prev.flynt.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  fondat = prev.fondat.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  forecast-solar = prev.forecast-solar.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { PACKAGE_VERSION = old.version; }
  );

  fsspec = prev.fsspec.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
    }
  );

  g4f = prev.g4f.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { env.G4F_VERSION = old.version; }
  );

  galaxy-fds-sdk = prev.galaxy-fds-sdk.overridePythonAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        if [ -f "pyproject.toml" ]; then
             substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
           fi

        touch README.md
      '';
  });

  galaxy-util = prev.galaxy-util.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  geojson-rewind = prev.geojson-rewind.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  geopandas = prev.geopandas.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  giant-mixins = prev.giant-mixins.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  gilknocker = prev.gilknocker.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  gino = prev.gino.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  glean-sdk = prev.glean-sdk.overridePythonAttrs (old: ((offlineMaturin { furtherArgs = { }; }) old));

  glpk = prev.glpk.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      buildInputs = old.buildInputs or [ ] ++ [ pkgs.glpk ];
    }
  );

  gmplot = prev.gmplot.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  gmpy2 = prev.gmpy2.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      buildInputs = with pkgs; [
        gmp
        mpfr
        libmpc
      ];
    }
  );

  grabbit = prev.grabbit.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  graia-application-mirai = prev.graia-application-mirai.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  graia-broadcast = prev.graia-broadcast.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  graphlib-backport = prev.graphlib-backport.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  grimp = prev.grimp.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = {
        cargoRoot = "rust";
      };
    } old)
  );

  grpc-requests = prev.grpc-requests.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  h3ronpy = prev.h3ronpy.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = {
        cargoRoot = "";

        cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = ./cargo.locks/h3ronpy/${old.version}.lock;

            outputHashes =
              let
                lookup = {
                  "0.19.2" = {
                    "h3arrow-0.2.0" = "sha256-AWPD9J98uoKoXAbOSdTJc/uCwMZr8Dm9DAoXC4rqtuU=";
                  };
                  "0.19.0" = {
                    "h3arrow-0.2.0" = "sha256-AWPD9J98uoKoXAbOSdTJc/uCwMZr8Dm9DAoXC4rqtuU=";
                  };
                  "0.17.0" = {
                    "geoarrow-0.0.1" = "sha256-++NQQ3wx1NoM0o+gQhp876E94u4o/WlDlBO7DShaKqk=";
                    "h3arrow-0.1.0" = "sha256-ZlIDgKt9V/ZADtvdB3JEbYobRgKA/iidfCl2txFN64g=";
                    "rasterh3-0.3.0" = "sha256-jp5Gbmyiw+pCP5QZwQF/3wxzpqEG5nMaXQ0Uu9mcwwo=";
                  };
                  "0.19.1" = {
                    "h3arrow-0.2.0" = "sha256-AWPD9J98uoKoXAbOSdTJc/uCwMZr8Dm9DAoXC4rqtuU=";
                  };
                };
              in
              lookup.${old.version} or { };
          };
      };
    } old)
  );

  hdfdict = prev.hdfdict.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  hdfs3 = prev.hdfs3.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  hieroglyph = prev.hieroglyph.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  hive-metastore-client = prev.hive-metastore-client.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  html2image = prev.html2image.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  http3 = prev.http3.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  httprunner = prev.httprunner.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  hwi = prev.hwi.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  ibis-framework = prev.ibis-framework.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  idds-common = prev.idds-common.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  imgsize = prev.imgsize.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  impyla = prev.impyla.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  incomfort-client = prev.incomfort-client.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  influxdb3-python = prev.influxdb3-python.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { GITHUB_REF = "ref/tags/v${old.version}"; }
  );

  intake = prev.intake.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  intake-geopandas = prev.intake-geopandas.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  intake-xarray = prev.intake-xarray.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  interpolation = prev.interpolation.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  intype = prev.intype.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  irctokens = prev.irctokens.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          echo "${old.version}" >VERSION 
        '';
    }
  );

  iterwrapper = prev.iterwrapper.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch readme.md
        '';
    }
  );

  itly-sdk = prev.itly-sdk.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  java-manifest = prev.java-manifest.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  ject = prev.ject.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  jellyfish = prev.jellyfish.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  jetblack-asgi-typing = prev.jetblack-asgi-typing.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  jiter = prev.jiter.overridePythonAttrs (old: ((offlineMaturin { furtherArgs = { }; }) old));

  kenlm = prev.kenlm.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  kurbopy = prev.kurbopy.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  lazytree = prev.lazytree.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  levenshtein = prev.levenshtein.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      preBuild = ''
        cd /build/Levenshtein-${old.version}
        find .
      '';
    }
  );

  libcst = prev.libcst.overridePythonAttrs (
    old:
    (standardMaturin {
      maturinHook = null;
      furtherArgs = {
        cargoRoot = "native";

        nativeBuildInputs = [
          pkgs.cargo
          pkgs.rustc
        ];
      };
    } old)
  );

  libhoney = prev.libhoney.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  libpysal = prev.libpysal.overridePythonAttrs (
    old:
    lib.optionalAttrs (old.version == "4.1.0") lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements_plus_conda.txt
          touch requirements_plus_pip.txt
          touch requirements_docs.txt
        '';
    }
  );

  librespot = prev.librespot.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  libthumbor = prev.libthumbor.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  license-expression = prev.license-expression.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontConfigure = true; }
  );

  liftover = prev.liftover.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      buildInputs = (old.buildInputs or { }) ++ [ pkgs.zlib ];
    }
  );

  ligotimegps = prev.ligotimegps.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  limits = prev.limits.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  link-feature = prev.link-feature.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  lintrunner = prev.lintrunner.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  liquidpy = prev.liquidpy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  logdna = prev.logdna.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  loggable-jdv = prev.loggable-jdv.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  lomond = prev.lomond.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch README.md
        '';
    }
  );

  lvis = prev.lvis.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  lxml = prev.lxml.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      # force cython regeneration
      buildInputs = old.buildInputs or [ ] ++ [ final.cython_0 ];
      postPatch =
        (old.postPatch or "")
        + ''
          find -name '*.c' -print0 | xargs -0 -r rm
        '';
    }
  );

  mabwiser = prev.mabwiser.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  mailer = prev.mailer.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
    }
  );

  mantichora = prev.mantichora.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  marshmallow-objects = prev.marshmallow-objects.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-fail ')' ', version="${old.version}")'
        '';
    }
  );

  matchpy = prev.matchpy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  matplotlib-scalebar = prev.matplotlib-scalebar.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  maturin = prev.maturin.overridePythonAttrs (old: standardMaturin { } old);

  memory-tempfile = prev.memory-tempfile.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  messages = prev.messages.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  mill-local = prev.mill-local.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  minijinja = prev.minijinja.overridePythonAttrs (old: ((offlineMaturin { furtherArgs = { }; }) old));

  mitmproxy-wireguard = prev.mitmproxy-wireguard.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  mixins = prev.mixins.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  mkdocstrings = prev.mkdocstrings.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  mocpy = prev.mocpy.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  model-index = prev.model-index.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  modelcards = prev.modelcards.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  modelscope = prev.modelscope.override {
    preferWheel = true; # does not have a setup.py just setup.cfg
  };

  module-wrapper = prev.module-wrapper.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  monai = prev.monai.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  msgpack = prev.msgpack.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  multicoretsne = prev.multicoretsne.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-fail 'self.cmake_args or "--"' 'self.cmake_args or ""'
        '';
      dontUseCmakeConfigure = true;
    }
  );

  multiprocess = prev.multiprocess.override { preferWheel = true; };

  muscima = prev.muscima.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  mwdblib = prev.mwdblib.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  nats-python = prev.nats-python.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  nbtlib = prev.nbtlib.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  ndindex = prev.ndindex.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  netifaces2 = prev.netifaces2.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  netmiko = prev.netmiko.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  networkit = prev.networkit.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  nevow = prev.nevow.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  nh3 = prev.nh3.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  nichelper = prev.nichelper.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  nidaqmx = prev.nidaqmx.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  nilspodlib = prev.nilspodlib.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  nornir = prev.nornir.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  nornir-napalm = prev.nornir-napalm.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  nornir-netmiko = prev.nornir-netmiko.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  nornir-utils = prev.nornir-utils.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  notmuch = prev.notmuch.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  numcodecs = prev.numcodecs.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      buildInputs = old.buildInputs ++ [ final.py-cpuinfo ];
    }
  );

  numpy-groupies = prev.numpy-groupies.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass = versioneer.get_cmdclass()" "" \
              --replace-quiet "cmdclass=cmdclass," "" \
              --replace-quiet "cmdclass=dict(clean=Clean, **versioneer.get_cmdclass())," "" \
              --replace-quiet "cmdclass.update(clean=NumpyGroupiesClean)" "" \
              --replace-quiet "cmdclass=dict(clean=NumpyGroupiesClean, **versioneer.get_cmdclass())," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  nutils-poly = prev.nutils-poly.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  nutter = prev.nutter.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  nvidia-ml-py3 = prev.nvidia-ml-py3.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  nvsmi = prev.nvsmi.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  ob = prev.ob.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  ocpp = prev.ocpp.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  odo = prev.odo.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  oead = prev.oead.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  onepasswordconnectsdk = prev.onepasswordconnectsdk.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  ontospy = prev.ontospy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  openapi-python-client = prev.openapi-python-client.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  opencv-contrib-python-headless = prev.opencv-contrib-python-headless.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          sed -i pyproject.toml -e 's/numpy==[0-9]\+\.[0-9]\+\.[0-9]\+;/numpy;/g'
          # somehow the type information doesn't get build
          substituteInPlace setup.py --replace-fail '[ r"python/cv2/py.typed" ] if sys.version_info >= (3, 6) else []' "[]" \
          --replace-fail 'rearrange_cmake_output_data["cv2.typing"] = ["python/cv2" + r"/typing/.*\.py"]' "pass"
        '';
      dontUseCmakeConfigure = true;
    }
  );

  opencv-python = prev.opencv-python.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          sed -i pyproject.toml -e 's/numpy==[0-9]\+\.[0-9]\+\.[0-9]\+;/numpy;/g'
          # somehow the type information doesn't get build
          substituteInPlace setup.py --replace-fail '[ r"python/cv2/py.typed" ] if sys.version_info >= (3, 6) else []' "[]" \
          --replace-fail 'rearrange_cmake_output_data["cv2.typing"] = ["python/cv2" + r"/typing/.*\.py"]' "pass"
        '';
    }
  );

  opencv-python-headless = prev.opencv-python-headless.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      meta.priority = 1;
      postPatch =
        (old.postPatch or "")
        + ''
          sed -i pyproject.toml -e 's/numpy==[0-9]\+\.[0-9]\+\.[0-9]\+;/numpy;/g'
          # somehow the type information doesn't get build
          substituteInPlace setup.py --replace-fail '[ r"python/cv2/py.typed" ] if sys.version_info >= (3, 6) else []' "[]" \
          --replace-fail 'rearrange_cmake_output_data["cv2.typing"] = ["python/cv2" + r"/typing/.*\.py"]' "pass"
        '';
    }
  );

  openevsewifi = prev.openevsewifi.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  openlineage-sql = prev.openlineage-sql.overridePythonAttrs (
    old:
    (offlineMaturin {
      furtherArgs = {
        cargoRoot = "";

        cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = ./cargo.locks/openlineage-sql/${old.version}.lock;

            outputHashes =
              let
                lookup = {
                  "0.19.1" = {
                    "sqlparser-0.25.0" = "sha256-5+fWQZ6J2V1V7NFEFSrGaEuJ6dBzJR2C1K6ONZfsY+Y=";
                  };
                  "0.19.2" = {
                    "sqlparser-0.25.0" = "sha256-5+fWQZ6J2V1V7NFEFSrGaEuJ6dBzJR2C1K6ONZfsY+Y=";
                  };
                  "0.20.4" = {
                    "sqlparser-0.25.0" = "sha256-5+fWQZ6J2V1V7NFEFSrGaEuJ6dBzJR2C1K6ONZfsY+Y=";
                  };
                  "0.20.6" = {
                    "sqlparser-0.25.0" = "sha256-5+fWQZ6J2V1V7NFEFSrGaEuJ6dBzJR2C1K6ONZfsY+Y=";
                  };
                  "0.21.0" = {
                    "sqlparser-0.30.0" = "sha256-93ODoShuB1x0SGycocufVX/yLqE25/S/1/6gR3j8VWY=";
                  };
                  "0.21.1" = {
                    "sqlparser-0.30.0" = "sha256-93ODoShuB1x0SGycocufVX/yLqE25/S/1/6gR3j8VWY=";
                  };
                  "0.22.0" = {
                    "sqlparser-0.32.0" = "sha256-RU3kZd6FbJ86fDe7tcZuqtbCiDK3onMIQTt0jGJroRY=";
                  };
                  "0.23.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.33.0" = "sha256-2fpR4pmbNvhhs3vYoNPC9BktRcfqYRCws/t9JXSCQj4=";
                  };
                  "0.24.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.33.0" = "sha256-QyuqR8VDJ2uIH3/rYqk/L4MI9sGa5wZjmg6lTy4upqM=";
                  };
                  "0.25.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.33.0" = "sha256-wEXYu+rn9A3yfDWN+lV13FxPI9vVsBppJOEAkZIKkp0=";
                  };
                  "0.26.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.33.0" = "sha256-ZCKhRt4dVtWu1fkQvDpirM46TGPWComXnytJruWNffE=";
                  };
                  "0.27.1" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.34.0" = "sha256-/ruvxMzNpFrH3cvme7V47ZAwcRwUuTb2NFdzhAc1Bl0=";
                  };
                  "0.27.2" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.34.0" = "sha256-/ruvxMzNpFrH3cvme7V47ZAwcRwUuTb2NFdzhAc1Bl0=";
                  };
                  "0.28.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.34.0" = "sha256-OTQqK3v4fOmk5YXrzvHI05bJw1319Digx3P3ldNHqAM=";
                  };
                  "0.29.2" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.35.0" = "sha256-j89NcMZfUJ6XBHxfXkacaSIeRNI2Tr6XXeBQC977TpI=";
                  };
                  "0.30.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.36.1" = "sha256-rTVNEWOA3kYhw00Cr6KERnVHMSlHURfcCVt0nPApTwk=";
                  };
                  "0.30.1" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.36.1" = "sha256-rTVNEWOA3kYhw00Cr6KERnVHMSlHURfcCVt0nPApTwk=";
                  };
                  "1.0.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.36.1" = "sha256-xXiffv5+5uMSgJMp2gfA0/j3fcCxIPNRuD3aH8LLZQI=";
                  };
                  "1.1.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                    "sqlparser-0.37.0" = "sha256-qvXGGIOEJ4nIa2WrV3C+pLpPazFVysREsL//+6pKSOc=";
                  };
                  "1.10.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.10.1" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.10.2" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.11.1" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.11.2" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.11.3" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.12.0" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.13.1" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.14.0" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.15.0" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.16.0" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.17.0" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.17.1" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.18.0" = {
                    "sqlparser-0.44.0" = "sha256-v++peshiP9ThK52Ss18F4Vd3qR2hR8FnTlfsOI8M0Jg=";
                  };
                  "1.2.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.2.1" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.2.2" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.3.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.3.1" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.4.1" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.5.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.6.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.6.1" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.6.2" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.7.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.8.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.9.0" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                  "1.9.1" = {
                    "sqlparser-0.32.0" = "sha256-PuZUhgNRgQ6d5oz+xQoSis/LLM+SBmeq3+EGRuFu81M=";
                  };
                };
              in
              lookup.${old.version} or { };
          };
      };
    } old)
  );

  opsdroid-get-image-size = prev.opsdroid-get-image-size.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch HISTORY.rst
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  opt-einsum = prev.opt-einsum.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  optree = prev.optree.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  orator = prev.orator.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  orjson = prev.orjson.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = {
        buildInputs =
          prev.orjson.buildInputs or [ ]
          ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];
        sourceRoot = lib.optionalString (lib.versionOlder old.version "3.6.0") ".";
        postPatch =
          (old.postPatch or "")
          + ''
            # if the file Cargo.toml contains [package.metadata.maturin]
            # then we cut out everything from [package.metadata.maturin] to the next empty line
            # in place
            # maturin > 0.14 doesn't like that anymore.
            sed -i -e '/^\[package.metadata.maturin\]/,/^$/d' Cargo.toml
            substituteInPlace "pyproject.toml" --replace-quiet 'strip = "on"' "strip = true"
            cat Cargo.toml
          '';
      };
    } old)
  );

  oslash = prev.oslash.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  outcome-utils = prev.outcome-utils.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  ovos-config = prev.ovos-config.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        if (old.version == "0.0.0") then
          ''
            touch requirements.txt
          ''
        else
          ''
            mkdir requirements
            touch requirements/requirements.txt
            touch requirements/extras.txt
          '';
    }
  );

  pandahouse = prev.pandahouse.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  pandas = prev.pandas.overridePythonAttrs (
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

  pandas-datareader = prev.pandas-datareader.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  partd = prev.partd.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
          touch requirements.txt
        '';
    }
  );

  pastel = prev.pastel.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  patch = prev.patch.overridePythonAttrs (
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

  patchify = prev.patchify.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pathmagic = prev.pathmagic.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pathpy = prev.pathpy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch HISTORY.rst
        '';
    }
  );

  pdfx = prev.pdfx.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pdoc-pyo3-sample-library = prev.pdoc-pyo3-sample-library.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  pelican = prev.pelican.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pendulum = prev.pendulum.overridePythonAttrs (
    old:
    if (lib.versionOlder old.version "2.2") then
      {
        # disable buliding of the c extension, requires distutils
        postPatch =
          (old.postPatch or "")
          + ''
            echo "def build(*args, **kwargs): pass" > build.py
            if [ -f pyproject.toml ]; then
              substituteInPlace pyproject.toml --replace-quiet "poetry.masonry.api" "poetry.core.masonry.api"
            fi
          '';
      }
    else
      (standardMaturin {
        furtherArgs = {
          cargoRoot = "rust";
        };
      } old)
  );

  phonopy = prev.phonopy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      dontUseCmakeConfigure = true;
      CMAKE_PREFIX_PATH = "${prev.nanobind}/lib/python${lib.versions.majorMinor final.python.version}/site-packages/nanobind/cmake";
    }
  );

  pickley = prev.pickley.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-fail 'versioning="dev"' 'version="${old.version}"'
        '';
    }
  );

  pipda = prev.pipda.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  piq = prev.piq.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pixivpy = prev.pixivpy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pm4py = prev.pm4py.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  poetry-semver = prev.poetry-semver.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  poetry-version = prev.poetry-version.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pokrok = prev.pokrok.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  poppy-core = prev.poppy-core.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  pprofile = prev.pprofile.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
    }
  );

  progressbar-ipython = prev.progressbar-ipython.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace progressbar/__init__.py \
            --replace-quiet "from compat import *" "from .compat import *" \
            --replace-quiet "from widgets import *" "from .widgets import *"
        '';
    }
  );

  prompter = prev.prompter.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  publicsuffix2 = prev.publicsuffix2.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { buildInputs = [ prev.requests ]; }
  );

  pvfactors = prev.pvfactors.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  pvlib = prev.pvlib.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  py-aiger = prev.py-aiger.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  py-aiger-bv = prev.py-aiger-bv.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pyannote-algorithms = prev.pyannote-algorithms.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  pyannote-core = prev.pyannote-core.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  pyannote-metrics = prev.pyannote-metrics.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  pyap = prev.pyap.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pyarr = prev.pyarr.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f pyproject.toml ]; then
            substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
          fi
          touch requirements.txt
        '';
    }
  );

  pyarrow = prev.pyarrow.override { preferWheel = true; };

  pyauto-core = prev.pyauto-core.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  pyauto-util = prev.pyauto-util.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  pycallgraph = prev.pycallgraph.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  pycddl = prev.pycddl.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = {
        cargoRoot = "";

        cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = ./cargo.locks/pycddl/${old.version}.lock;

            outputHashes =
              let
                lookup = {
                  "0.5.1" = {
                    "cddl-0.9.1" = "sha256-YTXobgdSRvhirOMTpBoTLxsH83VXwLqjxD02QJFVMLE=";
                  };
                };
              in
              lookup.${old.version} or { };
          };
      };
    } old)
  );

  pycrdt = prev.pycrdt.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  pydata-google-auth = prev.pydata-google-auth.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  pydicom-seg = prev.pydicom-seg.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pydot2 = prev.pydot2.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  pydriller = prev.pydriller.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pyfolio = prev.pyfolio.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  pyfunctional = prev.pyfunctional.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pygal = prev.pygal.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch README.md
          if [ -f setup.py ]; then
          substituteInPlace setup.py \
            --replace-quiet "use_2to3=True," "" \
            --replace-quiet "use_2to3=True" "" \
            --replace-quiet "use_2to3 = True," "" \
            --replace-quiet "use_2to3= bool(python_version >= 3.0)," "" \
            --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  pyglove = prev.pyglove.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pyhepmc = prev.pyhepmc.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  pyicu = prev.pyicu.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      nativeBuildInputs = [
        pkgs.icu
        prev.setuptools
      ];
      format = "pyproject";
      buildInputs = [ pkgs.icu ];
    }
  );

  pyknp = prev.pyknp.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pylibjpeg-openjpeg = prev.pylibjpeg-openjpeg.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  pylogbeat = prev.pylogbeat.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace 'setup.py' --replace-warn "rmtree(directory, ignore_errors=True)" "pass"
        '';
    }
  );

  pymannkendall = prev.pymannkendall.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  pymarshaler = prev.pymarshaler.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pymel = prev.pymel.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pymiscutils = prev.pymiscutils.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pymisp = prev.pymisp.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
           touch README.md
           if [ -f pyproject.toml ]; then
             substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
          fi
        '';
    }
  );

  pynetgear = prev.pynetgear.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pynng = prev.pynng.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  pynvml = prev.pynvml.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  pyopencl = prev.pyopencl.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      CMAKE_PREFIX_PATH = "${prev.nanobind}/lib/python${lib.versions.majorMinor final.python.version}/site-packages/nanobind/cmake";
      dontUseCmakeConfigure = true;
    }
  );

  pyownet = prev.pyownet.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  pyparam = prev.pyparam.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pypeln = prev.pypeln.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pyppeteer2 = prev.pyppeteer2.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pyquaternion = prev.pyquaternion.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          echo "${old.version}" >VERSION.txt
        '';
    }
  );

  pyrad = prev.pyrad.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pyrevm = prev.pyrevm.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  pysam = prev.pysam.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      buildInputs = old.buildInputs or [ ] ++ [
        pkgs.zlib
        pkgs.bzip2
        pkgs.xz
        pkgs.curl
      ];
    }
  );

  pysnmp = prev.pysnmp.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py \
           --replace-fail "observed_version = [int(x) for x in setuptools.__version__.split('.')]" "observed_version = [70,]"
        ''; # anything over 36.2.0 should be ok.
    }
  );

  pysnow = prev.pysnow.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pysnyk = prev.pysnyk.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pysubtypes = prev.pysubtypes.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pytest-docker-tools = prev.pytest-docker-tools.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pytest-golden = prev.pytest-golden.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pytest-mockservers = prev.pytest-mockservers.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pytest-reraise = prev.pytest-reraise.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pytest-spec = prev.pytest-spec.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pytextspan = prev.pytextspan.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  python-bidi = prev.python-bidi.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  python-box = prev.python-box.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch README.md
        '';
    }
  );

  python-creole = prev.python-creole.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  python-graph-core = prev.python-graph-core.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  python-ioc = prev.python-ioc.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  python-jsonrpc-server = prev.python-jsonrpc-server.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  python-language-server = prev.python-language-server.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  python-magic = prev.python-magic.overridePythonAttrs (
    old:
    let
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
    {
      postPatch = lib.optionalString (!isWheel) fixupScriptText;
      postFixup = lib.optionalString isWheel ''
        cd $out/${final.python.sitePackages}
        ${fixupScriptText}
      '';
      pythonImportsCheck = old.pythonImportsCheck or [ ] ++ [ "magic" ];
    }
  );

  python-mimeparse = prev.python-mimeparse.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  python-picnic-api = prev.python-picnic-api.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  python-pushover = prev.python-pushover.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  python-ranges = prev.python-ranges.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch readme.md
        '';
    }
  );

  python-simpleconf = prev.python-simpleconf.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  python-tado = prev.python-tado.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  python-telegram-bot = prev.python-telegram-bot.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  python-tlsh = prev.python-tlsh.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  python3-logstash = prev.python3-logstash.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch README.md
        '';
    }
  );

  pytkdocs = prev.pytkdocs.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pytm = prev.pytm.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pytorch-tabnet = prev.pytorch-tabnet.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  pyunitreport = prev.pyunitreport.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  pyvcf = prev.pyvcf.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""             '';
    }
  );

  pyvin = prev.pyvin.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  pywinpty = prev.pywinpty.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  pyxirr = prev.pyxirr.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  pyzoom = prev.pyzoom.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  qcs-api-client = prev.qcs-api-client.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  qdldl = prev.qdldl.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  qiskit = prev.qiskit.overridePythonAttrs (
    old:
    (
      (standardMaturin {
        maturinHook = null;
        furtherArgs = {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pkgs.rustc
            pkgs.cargo
          ];
        };
      })
      old
    )
  );

  qiskit-terra = prev.qiskit-terra.overridePythonAttrs (
    old:
    (
      (standardMaturin {
        maturinHook = null;
        furtherArgs = {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pkgs.rustc
            pkgs.cargo
          ];
        };
      })
      old
    )
  );

  qt5reactor = prev.qt5reactor.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  qtoml = prev.qtoml.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  quil = prev.quil.overridePythonAttrs (old: ((offlineMaturin { furtherArgs = { }; }) old));

  quimb = prev.quimb.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  quinn = prev.quinn.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  readmdict = prev.readmdict.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  reference-handler = prev.reference-handler.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  regress = prev.regress.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  regressors = prev.regressors.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  replit = prev.replit.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  resend = prev.resend.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  rfc6266 = prev.rfc6266.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  rfc7464 = prev.rfc7464.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
    }
  );

  rhino3dm = prev.rhino3dm.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  rich = prev.rich.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  roboflow = prev.roboflow.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  robotframework-seleniumtestability = prev.robotframework-seleniumtestability.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  royalnet = prev.royalnet.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  rpds-py = prev.rpds-py.overridePythonAttrs (
    old:
    (
      (standardMaturin {
        furtherArgs = {
          buildInputs = old.buildInputs or [ ] ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];
        };
      })
      old
    )
  );

  rpy2 = prev.rpy2.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch = lib.optionalString (old.version == "3.4.0") ''
        touch requirements.txt
      '';
      nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.R ];
      builtInputs = (old.buildInputs or [ ]) ++ [
        (
          (with pkgs.rPackages; [
            # packages expected by the test framework
            ggplot2
            dplyr
            RSQLite
            broom
            DBI
            dbplyr
            hexbin
            lazyeval
            lme4
            tidyr
          ])
          ++ pkgs.rWrapper.recommendedPackages
        )
      ];
      # buildInputs is not enough with the poetry2nix hooks
      NIX_LDFLAGS =
        (lib.optionalString (lib.versionAtLeast old.version "3.5.13") "-L${pkgs.bzip2.out}/lib -L${pkgs.xz.out}/lib -L${pkgs.zlib.out}/lib -L${pkgs.icu.out}/lib")
        + (lib.optionalString (lib.versionOlder old.version "3.0.0") "-L${pkgs.readline.out}/lib");
    }
  );

  rqdatac = prev.rqdatac.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  rsoup = prev.rsoup.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  rtoml = prev.rtoml.overridePythonAttrs (
    old:
    (
      (standardMaturin {
        maturinHook = null;
        furtherArgs = {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pkgs.rustc
            pkgs.cargo
          ];
        };
      })
      old
    )
  );

  runez = prev.runez.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-fail 'versioning="dev"' 'version="${old.version}"'
        '';
    }
  );

  runipy = prev.runipy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
    }
  );

  rustworkx = prev.rustworkx.overridePythonAttrs (
    old:
    (
      (standardMaturin {
        maturinHook = null;
        furtherArgs = {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pkgs.rustc
            pkgs.cargo
          ];
        };
      })
      old
    )
  );

  safetensors = prev.safetensors.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = {
        cargoRoot = "bindings/python";
      };
    } old)
  );

  scikit-base = prev.scikit-base.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  scikit-image = prev.scikit-image.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          patchShebangs skimage/_build_utils/{version,cythoner}.py
        '';
    }
  );

  scikit-surgeryarucotracker = prev.scikit-surgeryarucotracker.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  scikit-surgeryimage = prev.scikit-surgeryimage.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  scim2-filter-parser = prev.scim2-filter-parser.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  scrapelib = prev.scrapelib.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  scs = prev.scs.overridePythonAttrs (
    old:
    let
      blas = old.passthru.args.blas or pkgs.openblasCompat;
    in
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      buildInputs = old.buildInputs or [ ] ++ [
        blas
        pkgs.lapack
      ];
      dontUseCmakeConfigure = true;
    }
  );

  setuptools-scm-git-archive = prev.setuptools-scm-git-archive.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-quiet "setuptools-scm<8" "setuptools-scm"
        '';
    }
  );

  sevenbridges-python = prev.sevenbridges-python.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  sharkiq = prev.sharkiq.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  simplug = prev.simplug.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  siphon = prev.siphon.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  skytemple-rust = prev.skytemple-rust.overridePythonAttrs (
    old:
    (
      (standardMaturin {
        maturinHook = null;
        furtherArgs = {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pkgs.rustc
            pkgs.cargo
          ];
        };
      })
      old
    )
  );

  solders = prev.solders.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  solidpython = prev.solidpython.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  spaceone-api = prev.spaceone-api.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { PACKAGE_VERSION = old.version; }
  );

  spacy-alignments = prev.spacy-alignments.overridePythonAttrs (
    old:
    (
      (standardMaturin {
        maturinHook = null;
        furtherArgs = {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pkgs.rustc
            pkgs.cargo
          ];
        };
      })
      old
    )
  );

  sparqlwrapper = prev.sparqlwrapper.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  sparse-dot-topn = prev.sparse-dot-topn.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      dontUseCmakeConfigure = true;
      CMAKE_PREFIX_PATH = "${prev.nanobind}/lib/python${lib.versions.majorMinor final.python.version}/site-packages/nanobind/cmake";
    }
  );

  spglib = prev.spglib.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  sphinx-argparse = prev.sphinx-argparse.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch README.md
        '';
    }
  );

  sphinx-data-viewer = prev.sphinx-data-viewer.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  sphinx-markdown-parser = prev.sphinx-markdown-parser.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  splink = prev.splink.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  spreg = prev.spreg.overridePythonAttrs (
    old:
    lib.optionalAttrs (lib.versionOlder old.version "1.0.1") {
      postPatch =
        (old.patchPhase or "")
        + ''
          ls -la 
          cd /build/${old.pname}-${old.version}
            touch requirements.txt
            touch requirements_plus.txt
            touch requirements_dev.txt
          ls -la
        '';
    }
  );

  spylls = prev.spylls.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  sqlglotrs = prev.sqlglotrs.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  starlette-prometheus = prev.starlette-prometheus.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  stdlib-list = prev.stdlib-list.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  stegano = prev.stegano.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  stomp-py = prev.stomp-py.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  streamerate = prev.streamerate.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  strenum = prev.strenum.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  strip-ansi = prev.strip-ansi.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  stripe = prev.stripe.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  suitcase-msgpack = prev.suitcase-msgpack.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  suitcase-utils = prev.suitcase-utils.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + (lib.optionalString (lib.versionOlder old.version "1.0.1") ''
          touch requirements.txt
        '')
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  swiglpk = prev.swiglpk.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      buildInputs = old.buildInputs or [ ] ++ [ pkgs.glpk ];
      nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.swig ];
      env = {
        GLPK_HEADER_PATH = "${pkgs.glpk}/include";
      };
    }
  );

  symengine = prev.symengine.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      env = {
        SymEngine_DIR = "${pkgs.symengine}";
      };

      patches = [
        # Distutils has been removed in python 3.12
        # See https://github.com/symengine/symengine.py/pull/478
        (pkgs.fetchpatch {
          name = "no-distutils.patch";
          url = "https://github.com/symengine/symengine.py/pull/478/commits/e72006d5f7425cd50c54b22766e0ed4bcd2dca85.patch";
          hash = "sha256-kGJRGkBgxOfI1wf88JwnSztkOYd1wvg62H7wA6CcYEQ=";
        })
      ];

      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py \
            --replace-fail "\"cmake\"" "\"${lib.getExe' pkgs.cmake "cmake"}\"" \
            --replace-fail "'cython>=0.29.24'" "'cython'"

          export PATH=${prev.cython}/bin:$PATH
        '';
    }
  );

  synologydsm-api = prev.synologydsm-api.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  tables = prev.tables.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.pkg-config ];
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py \
                  --replace-warn "shutil.copy(libdir / \"libblosc2.so\", ROOT / \"tables\")" ""
        '';
      buildInputs =
        old.buildInputs or [ ]
        ++ (with pkgs; [
          bzip2
          c-blosc
          c-blosc2
          hdf5
          lzo
        ]);
      LZO_DIR = "${lib.getDev pkgs.lzo}";
      BZIP2_DIR = "${lib.getDev pkgs.bzip2}";
      HDF5_DIR = "${lib.getDev pkgs.hdf5}";
      BLOSC_DIR = "${lib.getDev pkgs.c-blosc}";
      BLOSC2_DIR = "${lib.getDev pkgs.c-blosc2}";
    }
  );

  tabulator = prev.tabulator.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  tartiflette = prev.tartiflette.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  taskipy = prev.taskipy.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  telfhash = prev.telfhash.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  tempita = prev.tempita.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  tendril-utils-core = prev.tendril-utils-core.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  tendril-utils-fsutils = prev.tendril-utils-fsutils.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  tendril-utils-yaml = prev.tendril-utils-yaml.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  texting = prev.texting.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  thrift = prev.thrift.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  tiktoken = prev.tiktoken.overridePythonAttrs (
    old:
    (
      (standardMaturin {
        maturinHook = null;
        furtherArgs = {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
            pkgs.rustc
            pkgs.cargo
          ];
        };
      })
      old
    )
    // {
      postPatch =
        let
          cargo_lock_filename = ./. + "/cargo.locks/${old.pname}/${old.version}.lock";
          cargo_lock =
            if builtins.pathExists cargo_lock_filename then
              cargo_lock_filename
            else
              throw "poetry2nix has no cargo.lock available for ${old.pname} ${old.version} and the python package does not include it.";
        in
        (old.postPatch or "")
        + ''
          cp ${cargo_lock} Cargo.lock
        '';
    }
  );

  timing-asgi = prev.timing-asgi.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  tinydb-serialization = prev.tinydb-serialization.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  tlparse = prev.tlparse.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  tmb = prev.tmb.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { env.VERSION = old.version; }
  );

  tokenizers = prev.tokenizers.overridePythonAttrs (
    old:
    (standardMaturin {
      furtherArgs = {
        cargoRoot = "bindings/python";
      };
    } old)
  );

  tomlkit = prev.tomlkit.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  topgrade = prev.topgrade.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  torch-fidelity = prev.torch-fidelity.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  torchao = prev.torchao.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  tortoise-orm = prev.tortoise-orm.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  tpdcc-config = prev.tpdcc-config.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  tpdcc-core = prev.tpdcc-core.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
      meta.priority = 2;
    }
  );

  tpdcc-dccs-maya = prev.tpdcc-dccs-maya.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  tpdcc-libs-nameit = prev.tpdcc-libs-nameit.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  tpdcc-libs-plugin = prev.tpdcc-libs-plugin.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  tpdcc-libs-python = prev.tpdcc-libs-python.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      meta.priority = 1;
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
            --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""             '';
    }
  );

  tpdcc-libs-qt = prev.tpdcc-libs-qt.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  tpdcc-libs-resources = prev.tpdcc-libs-resources.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  tpdcc-tools-nameit = prev.tpdcc-tools-nameit.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  tprigtoolkit-config = prev.tprigtoolkit-config.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      meta.priority = 1;
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  tprigtoolkit-core = prev.tprigtoolkit-core.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      meta.priority = 2;
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  trading-calendars = prev.trading-calendars.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  traits = prev.traits.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py                 --replace-quiet "use_2to3=True," ""                 --replace-quiet "use_2to3=True" ""                 --replace-quiet "use_2to3 = True," ""                 --replace-quiet "use_2to3= bool(python_version >= 3.0)," ""                 --replace-quiet "extra_setup_params[\"use_2to3\"] = True" ""
          fi
        '';
    }
  );

  trame-client = prev.trame-client.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  translatehtml = prev.translatehtml.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  trio-chrome-devtools-protocol = prev.trio-chrome-devtools-protocol.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  twitchio = prev.twitchio.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  typer = prev.typer.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  types-pyopenssl = prev.types-pyopenssl.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  types-pyside2 = prev.types-pyside2.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  types-setuptools = prev.types-setuptools.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  tzfpy = prev.tzfpy.overridePythonAttrs (old: ((standardMaturin { furtherArgs = { }; }) old));

  ultimate-hosts-blacklist-helpers = prev.ultimate-hosts-blacklist-helpers.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  ultralytics-thop = prev.ultralytics-thop.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  unicorn = prev.unicorn.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      # from nixpkgs.
      prePatch = ''
        ln -s ${pkgs.unicorn-emu}/lib/libunicorn.* prebuilt/
      '';
    }
  );

  unimatrix = prev.unimatrix.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  unimatrix-ext-etc = prev.unimatrix-ext-etc.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  upb-lib = prev.upb-lib.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  upnpclient = prev.upnpclient.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  username = prev.username.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch readme.md
        '';
    }
  );

  uuid-utils = prev.uuid-utils.overridePythonAttrs (
    old: ((standardMaturin { furtherArgs = { }; }) old)
  );

  uuid6 = prev.uuid6.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) { env.GITHUB_REF = "refs/tags/${old.version}"; }
  );

  uv = prev.uv.overridePythonAttrs (
    old:
    (offlineMaturin {
      furtherArgs = {
        dontUseCmakeConfigure = true;
        cargoRoot = "";

        cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = ./cargo.locks/uv/${old.version}.lock;

            outputHashes =
              let
                lookup = {
                  "0.2.24" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                    "reqwest-middleware-0.3.2" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                    "reqwest-retry-0.7.0" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                  };
                  "0.2.18" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                  };
                  "0.2.14" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                  };
                  "0.2.22" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                    "reqwest-middleware-0.3.2" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                    "reqwest-retry-0.7.0" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                  };
                  "0.2.6" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-DtUK5k7Hfl5h9nFSSeD2zm4wBiVo4tScvFTUQWxTYlU=";
                  };
                  "0.2.17" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                  };
                  "0.2.23" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                    "reqwest-middleware-0.3.2" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                    "reqwest-retry-0.7.0" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                  };
                  "0.2.11" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-i1Eaip4J5VXb66p1w0sRjP655AngBLEym70ChbAFFIc=";
                  };
                  "0.2.19" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                    "reqwest-middleware-0.3.2" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                    "reqwest-retry-0.7.0" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                  };
                  "0.2.7" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-DtUK5k7Hfl5h9nFSSeD2zm4wBiVo4tScvFTUQWxTYlU=";
                  };
                  "0.2.9" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-i1Eaip4J5VXb66p1w0sRjP655AngBLEym70ChbAFFIc=";
                  };
                  "0.2.16" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                  };
                  "0.2.10" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-i1Eaip4J5VXb66p1w0sRjP655AngBLEym70ChbAFFIc=";
                  };
                  "0.2.8" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-i1Eaip4J5VXb66p1w0sRjP655AngBLEym70ChbAFFIc=";
                  };
                  "0.2.13" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-i1Eaip4J5VXb66p1w0sRjP655AngBLEym70ChbAFFIc=";
                  };
                  "0.2.21" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                    "reqwest-middleware-0.3.2" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                    "reqwest-retry-0.7.0" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                  };
                  "0.2.15" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                  };
                  "0.2.12" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-i1Eaip4J5VXb66p1w0sRjP655AngBLEym70ChbAFFIc=";
                  };
                  "0.2.20" = {
                    "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
                    "pubgrub-0.2.1" = "sha256-6tr+HATYSn1A1uVJwmz40S4yLDOJlX8vEokOOtdFG0M=";
                    "reqwest-middleware-0.3.2" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                    "reqwest-retry-0.7.0" = "sha256-OiC8Kg+F2eKy7YNuLtgYPi95DrbxLvsIKrKEeyuzQTo=";
                  };
                };
              in
              lookup.${old.version} or { };
          };
      };
    } old)
  );

  valley = prev.valley.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f pyproject.toml ]; then
            substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
          fi
          touch requirements.txt
        '';
    }
  );

  varname = prev.varname.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  vbml = prev.vbml.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  vcard = prev.vcard.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  vega = prev.vega.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f pyproject.toml ]; then
            substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
          fi
          touch README.md
        '';
    }
  );

  veho = prev.veho.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  venv-pack = prev.venv-pack.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" "" 
          fi
        '';
    }
  );

  vsts = prev.vsts.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { meta.priority = 1; }
  );

  warrant-lite = prev.warrant-lite.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
          if [ -f pyproject.toml ]; then
             substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
          fi
        '';
    }
  );

  webdrivermanager = prev.webdrivermanager.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
            touch requirements.txt
            if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-quiet "versioneer.get_version()" "'${old.version}'" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()," "" \
              --replace-quiet "cmdclass=versioneer.get_cmdclass()" ""
          fi
        '';
    }
  );

  xatlas = prev.xatlas.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  xbbg = prev.xbbg.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  xdg = prev.xdg.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  xgboost = prev.xgboost.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  xpath-expressions = prev.xpath-expressions.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace pyproject.toml --replace "poetry.masonry.api" "poetry.core.masonry.api"
        '';
    }
  );

  yamlconf = prev.yamlconf.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  yolov5 = prev.yolov5.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  your = prev.your.overridePythonAttrs (
    old:
    lib.optionalAttrs (!(old.src.isWheel or false)) {
      postPatch =
        (old.postPatch or "")
        + ''
          touch requirements.txt
        '';
    }
  );

  z3-solver = prev.z3-solver.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );

  zxing-cpp = prev.zxing-cpp.overridePythonAttrs (
    old: lib.optionalAttrs (!(old.src.isWheel or false)) { dontUseCmakeConfigure = true; }
  );
}
