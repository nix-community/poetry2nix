{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
}:

let
  addBuildSystem' =
    { final
    , drv
    , attr
    , extraAttrs ? [ ]
    }:
    let
      buildSystem =
        if builtins.isAttrs attr then
          let
            fromIsValid =
              if builtins.hasAttr "from" attr then
                lib.versionAtLeast drv.version attr.from
              else
                true;
            untilIsValid =
              if builtins.hasAttr "until" attr then
                lib.versionOlder drv.version attr.until
              else
                true;
            intendedBuildSystem =
              if lib.elem attr.buildSystem [ "cython" "cython_0" ] then
                (final.python.pythonOnBuildForHost or final.python.pythonForBuild).pkgs.${attr.buildSystem}
              else
                final.${attr.buildSystem};
          in
          if fromIsValid && untilIsValid then intendedBuildSystem else null
        else
          if lib.elem attr [ "cython" "cython_0" ] then
            (final.python.pythonOnBuildForHost or final.python.pythonForBuild).pkgs.${attr}
          else
            final.${attr};
    in
    if (attr == "flit-core" || attr == "flit" || attr == "hatchling") && !final.isPy3k then drv
    else if drv == null then null
    else if !drv ? overridePythonAttrs then drv
    else
      drv.overridePythonAttrs (
        old:
        # We do not need the build system for wheels.
        if old ? format && old.format == "wheel" then
          { }
        else if attr == "poetry" then
          {
            # replace poetry
            postPatch = (old.postPatch or "") + ''
              if [ -f pyproject.toml ]; then
                toml="$(mktemp)"
                yj -tj < pyproject.toml | jq --from-file ${./poetry-to-poetry-core.jq} | yj -jt > "$toml"
                mv "$toml" pyproject.toml
              fi
            '';
            nativeBuildInputs = old.nativeBuildInputs or [ ]
              ++ [ final.poetry-core final.pkgs.yj final.pkgs.jq ]
              ++ map (a: final.${a}) extraAttrs;
          }
        else
          {
            nativeBuildInputs =
              old.nativeBuildInputs or [ ]
              ++ lib.optionals (!(builtins.isNull buildSystem)) [ buildSystem ]
              ++ map (a: final.${a}) extraAttrs;
          }
      );

  notNull = x: !(builtins.isNull x);
  sharedLibExt = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
  removePackagesByName = packages: packagesToRemove:
    let
      namesToRemove = map lib.getName (lib.filter notNull packagesToRemove);
    in
    lib.filter (x: !(builtins.elem (lib.getName x) namesToRemove)) packages;

in
lib.composeManyExtensions [
  # NixOps
  (final: prev:
    lib.mapAttrs (_: v: addBuildSystem' { inherit final; drv = v; attr = "poetry"; }) (lib.filterAttrs (n: _: lib.strings.hasPrefix "nixops" n) prev)
    // {
      # NixOps >=2 dependency
      nixos-modules-contrib = addBuildSystem' { inherit final; drv = prev.nixos-modules-contrib; attr = "poetry"; };
    }
  )

  # Add build systems
  (final: prev:
    let
      buildSystems = lib.importJSON ./build-systems.json;
    in
    lib.mapAttrs
      (attr: systems: builtins.foldl'
        (drv: attr: addBuildSystem' {
          inherit drv final attr;
        })
        (prev.${attr} or null)
        systems)
      buildSystems)

  # Build fixes
  (final: prev:
    let
      inherit (final.python) stdenv;
      inherit (pkgs.buildPackages) pkg-config cmake swig jdk gfortran meson ninja autoconf automake libtool;
      pyBuildPackages = (final.python.pythonOnBuildForHost or final.python.pythonForBuild).pkgs;

      selectQt5 = version:
        let
          selector = builtins.concatStringsSep "" (lib.take 2 (builtins.splitVersion version));
        in
          pkgs."qt${selector}" or pkgs.qt5;

      pyQt5Modules = qt5: with qt5; [
        qt3d
        qtbase
        qtcharts
        qtconnectivity
        qtdatavis3d
        qtdeclarative
        qtgamepad
        qtlocation
        qtmultimedia
        qtsensors
        qtserialport
        qtsvg
        qtwebchannel
        qtwebengine
        qtwebsockets
        qtx11extras
        qtxmlpatterns
      ];

      bootstrappingBase = (pkgs.${final.python.pythonAttr}.pythonOnBuildForHost or pkgs.${final.python.pythonAttr}.pythonForBuild).pkgs;

      # Build gdal without python bindings to prevent version mixing
      # We're only interested in the native libraries, not the python ones
      # as we build that separately.
      gdal = (pkgs.gdal.override { useJava = false; }).overrideAttrs (old: {
        doInstallCheck = false;
        doCheck = false;
        cmakeFlags = old.cmakeFlags or [ ] ++ [ "-DBUILD_PYTHON_BINDINGS=OFF" ];
      });
      tensorflowAttrs = {
        postInstall = ''
          rm $out/bin/tensorboard
        '';
      };
    in

    {
      addBuildSystem = attr: drv: addBuildSystem' { inherit final drv attr; };

      #### BEGIN bootstrapping pkgs
      installer = bootstrappingBase.installer.override {
        inherit (final) buildPythonPackage flit-core;
      };

      build = bootstrappingBase.build.override {
        inherit (final) buildPythonPackage flit-core packaging pyproject-hooks tomli;
      };

      flit-core = bootstrappingBase.flit-core.override {
        inherit (final) buildPythonPackage flit;
      };

      packaging = bootstrappingBase.packaging.override {
        inherit (final) buildPythonPackage flit-core;
      };

      tomli = bootstrappingBase.tomli.override {
        inherit (final) buildPythonPackage flit-core;
      };

      pyproject-hooks = bootstrappingBase.pyproject-hooks.override {
        inherit (final) buildPythonPackage flit-core tomli;
      };

      wheel = bootstrappingBase.wheel.override {
        inherit (final) buildPythonPackage flit-core;
      };

      inherit (bootstrappingBase) cython cython_0;
      #### END bootstrapping pkgs

      poetry = final.poetry-core;

      automat = prev.automat.overridePythonAttrs (
        old: lib.optionalAttrs (lib.versionOlder old.version "22.10.0") {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.m2r ];
        }
      );

      aiokafka = prev.aiokafka.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.zlib ];
      });

      aiohttp-swagger3 = prev.aiohttp-swagger3.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      ansible = prev.ansible.overridePythonAttrs (
        old: {
          # Inputs copied from nixpkgs as ansible doesn't specify it's dependencies
          # in a correct manner.
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            final.pycrypto
            final.paramiko
            final.jinja2
            final.pyyaml
            final.httplib2
            final.six
            final.netaddr
            final.dnspython
            final.jmespath
            final.dopy
            final.ncclient
          ];
        }
      );

      ansible-base = prev.ansible-base.overridePythonAttrs (
        old:
        {
          prePatch = ''sed -i "s/\[python, /[/" lib/ansible/executor/task_executor.py'';
          postInstall = ''
            for m in docs/man/man1/*; do
                install -vD $m -t $out/share/man/man1
            done
          '';
        }
        // lib.optionalAttrs (lib.versionOlder old.version "2.4") {
          prePatch = ''sed -i "s,/usr/,$out," lib/ansible/constants.py'';
        }
      );

      ansible-lint = prev.ansible-lint.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.setuptools-scm ];
          preBuild = ''
            export HOME=$(mktemp -d)
          '';
        }
      );

      argcomplete = prev.argcomplete.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.importlib-metadata ];
        }
      );

      arpeggio = prev.arpeggio.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      astroid = prev.astroid.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      av = prev.av.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.ffmpeg_4 ];
        }
      );

      apache-flink-libraries = prev.apache-flink-libraries.overridePythonAttrs (_old: {
        # apache-flink and apache-flink-libraries both install version.py into the
        # pyflink output derivation, which is invalid: whichever gets installed
        # last will be used
        postInstall = ''
          rm $out/${final.python.sitePackages}/pyflink/{README.txt,version.py,__pycache__/version.*.pyc}
        '';
      });

      apsw = prev.apsw.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            # without this patch a download of sqlite is attempted
            substituteInPlace setup.py --replace-warn 'if self.fetch:' 'if False:'
          '';
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.sqlite ];
        }
      );

      autoawq-kernels = prev.autoawq-kernels.overridePythonAttrs (_attrs: {
        autoPatchelfIgnoreMissingDeps = true;
      });

      avro-python3 = prev.avro-python3.overridePythonAttrs (attrs: {
        nativeBuildInputs = attrs.nativeBuildInputs or [ ]
          ++ [ final.isort final.pycodestyle ];
      });

      aws-cdk-asset-node-proxy-agent-v6 = prev.aws-cdk-asset-node-proxy-agent-v6.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'setuptools~=67.3.2' 'setuptools'
          '';
        }
      );

      aws-cdk-asset-awscli-v1 = prev.aws-cdk-asset-awscli-v1.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'setuptools~=67.3.2' 'setuptools'
          '';
        }
      );

      aws-cdk-asset-kubectl-v20 = prev.aws-cdk-asset-kubectl-v20.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'setuptools~=62.1.0' 'setuptools' \
              --replace-warn 'wheel~=0.37.1' 'wheel'
          '';
        }
      );

      aws-cdk-lib = prev.aws-cdk-lib.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'setuptools~=67.3.2' 'setuptools'
          '';
        }
      );

      awscrt = prev.awscrt.overridePythonAttrs (
        old: {
          nativeBuildInputs = [ cmake ] ++ old.nativeBuildInputs or [ ];
          dontUseCmakeConfigure = true;
        }
      );

      awsume = prev.awsume.overridePythonAttrs (_: {
        preBuild = ''
          HOME="$(mktemp -d)"
          export HOME
        '';
      });

      bcrypt =
        let
          getCargoHash = version: {
            "4.0.0" = "sha256-HvfRLyUhlXVuvxWrtSDKx3rMKJbjvuiMcDY6g+pYFS0=";
            "4.0.1" = "sha256-lDWX69YENZFMu7pyBmavUZaalGvFqbHSHfkwkzmDQaY=";
            "4.1.1" = "sha256-QYg1+DsZEdXB74vuS4SFvV0n5GXkuwHkOS9j1ogSTjA=";
            "4.1.2" = "sha256-fTD1AKvyeni5ukYjK53gueKLey+rcIUjW/0R289xeb0=";
            "4.1.3" = "sha256-Uag1pUuis5lpnus2p5UrMLa4HP7VQLhKxR5TEMfpK0s=";
            "4.2.0" = "sha256-dOS9A3pTwXYkzPFFNh5emxJw7pSdDyY+mNIoHdwNdmg=";
            "4.2.1" = "sha256-vbGF0oOhEDg3QIyQ0lASqbWtTWXiPAmGMnlF9I+hU78=";
            "4.3.0" = "sha256-92MEpnrUhdqpgMuXicy9c5gfdXYY0eq5Ak9fvNXAgMk=";
          }.${version} or (
            lib.warn "Unknown bcrypt version: '${version}'. Please update getCargoHash." lib.fakeHash
          );
        in
        prev.bcrypt.overridePythonAttrs (
          old: {
            buildInputs = old.buildInputs or [ ]
              ++ [ pkgs.libffi ]
              ++ lib.optionals (lib.versionAtLeast old.version "4" && stdenv.isDarwin)
              [ pkgs.darwin.apple_sdk.frameworks.Security pkgs.libiconv ];
            nativeBuildInputs = with pkgs;
              old.nativeBuildInputs or [ ]
                ++ lib.optionals (lib.versionAtLeast old.version "4") [ rustc cargo pkgs.rustPlatform.cargoSetupHook final.setuptools-rust ];
          } // lib.optionalAttrs (lib.versionAtLeast old.version "4") {
            cargoDeps =
              pkgs.rustPlatform.fetchCargoTarball
                {
                  inherit (old) src;
                  sourceRoot = "${old.pname}-${old.version}/src/_bcrypt";
                  name = "${old.pname}-${old.version}";
                  sha256 = getCargoHash old.version;
                };
            cargoRoot = "src/_bcrypt";
          }
        );
      bjoern = prev.bjoern.overridePythonAttrs (
        old: {
          buildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.libev ];
        }
      );

      borgbackup = prev.borgbackup.overridePythonAttrs (
        old: {
          BORG_OPENSSL_PREFIX = pkgs.openssl.dev;
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.openssl pkgs.acl ];
        }
      );

      bitsandbytes = prev.bitsandbytes.overridePythonAttrs (_attrs: {
        autoPatchelfIgnoreMissingDeps = true;
      });

      cairocffi = prev.cairocffi.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
          # apply necessary patches in postInstall if the source is a wheel
          postInstall = lib.optionalString (old.src.isWheel or false) ''
            pushd "$out/${final.python.sitePackages}"
            for patch in ${lib.concatMapStringsSep " " (p: "${p}") pkgs.python3.pkgs.cairocffi.patches}; do
              patch -p1 < "$patch"
            done
            popd
          '';
        } // lib.optionalAttrs (!(old.src.isWheel or false)) {
          inherit (pkgs.python3.pkgs.cairocffi) patches;
        }
      );

      cairosvg = prev.cairosvg.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      cattrs = prev.cattrs.overridePythonAttrs (
        old: lib.optionalAttrs (old.version == "1.10.0") {
          # 1.10.0 contains a pyproject.toml that requires a pre-release Poetry
          # We can avoid using Poetry and use the generated setup.py
          preConfigure = old.preConfigure or "" + ''
            rm pyproject.toml
          '';
        }
      );

      ccxt = prev.ccxt.overridePythonAttrs (_old: {
        preBuild = ''
          ln -s README.{rst,md}
        '';
      });

      cdk-nag = prev.cdk-nag.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'setuptools~=67.3.2' 'setuptools'
          '';
        }
      );

      celery = prev.celery.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
      });

      cerberus = prev.cerberus.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
      });

      constructs = prev.constructs.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'setuptools~=67.3.2' 'setuptools'
          '';
        }
      );

      cssselect2 = prev.cssselect2.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      cffi =
        # cffi is bundled with pypy
        if final.python.implementation == "pypy" then null else
        (
          prev.cffi.overridePythonAttrs (
            old: {
              nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
              buildInputs = old.buildInputs or [ ] ++ [ pkgs.libffi ];
              prePatch = (old.prePatch or "") + lib.optionalString (!(old.src.isWheel or false) && stdenv.isDarwin) ''
                # Remove setup.py impurities
                substituteInPlace setup.py --replace-warn "'-iwithsysroot/usr/include/ffi'" ""
                substituteInPlace setup.py --replace-warn "'/usr/include/ffi'," ""
                substituteInPlace setup.py --replace-warn '/usr/include/libffi' '${lib.getDev pkgs.libffi}/include'
              '';

            }
          )
        );

      cmdstanpy = prev.cmdstanpy.overridePythonAttrs (
        old:
        let
          fixupScriptText = ''
            substituteInPlace cmdstanpy/model.py \
              --replace-warn 'cmd = [make]' \
              'cmd = ["${pkgs.cmdstan}/bin/stan"]'
          '';
          isWheel = old.src.isWheel or false;
        in
        {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.cmdstan ];
          patchPhase = lib.optionalString (!isWheel) fixupScriptText;
          postFixup = lib.optionalString isWheel ''
            cd $out/${final.python.sitePackages}
            ${fixupScriptText}
          '';
          CMDSTAN = "${pkgs.cmdstan}";
        }
      );

      contourpy = prev.contourpy.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          dontUseMesonConfigure = true;
          postPatch = ''
            substituteInPlace pyproject.toml --replace-warn 'meson[ninja]' 'meson'
          '';
        }
      );

      clarabel = prev.dbt-extractor.overridePythonAttrs
        (
          old: {
            nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.cargo pkgs.rustc pkgs.maturin ];
          }
        );

      cloudflare = prev.cloudflare.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            rm -rf examples/*
          '';
        }
      );

      colour = prev.colour.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          patches = old.patches or [ ] ++ [
            (pkgs.fetchpatch {
              url = "https://raw.githubusercontent.com/NixOS/nixpkgs/485bbe58365f3c44a42f87b8cec2385b88380d74/pkgs/development/python-modules/colour/remove-unmaintained-d2to1.diff";
              hash = "sha256-Bj01qQlBd2oydv0afLV2Puqquuo3bnOOyDp7FR8cQnA=";
            })
          ];
        }
      );

      coincurve = prev.coincurve.overridePythonAttrs (
        _old: {
          # package setup logic
          LIB_DIR = "${lib.getLib pkgs.secp256k1}/lib";

          # for actual C toolchain build
          NIX_CFLAGS_COMPILE = "-I ${lib.getDev pkgs.secp256k1}/include";
          NIX_LDFLAGS = "-L ${lib.getLib pkgs.secp256k1}/lib";
        }
      );

      configparser = prev.configparser.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            final.toml
          ];
        }
      );

      confluent-kafka = prev.confluent-kafka.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            pkgs.rdkafka
          ];
        }
      );

      copier = prev.copier.overrideAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.git ];
      });

      cryptography =
        let
          getCargoHash = version: {
            "35.0.0" = "sha256-tQoQfo+TAoqAea86YFxyj/LNQCiViu5ij/3wj7ZnYLI=";
            "36.0.0" = "sha256-Y6TuW7AryVgSvZ6G8WNoDIvi+0tvx8ZlEYF5qB0jfNk=";
            "36.0.1" = "sha256-kozYXkqt1Wpqyo9GYCwN08J+zV92ZWFJY/f+rulxmeQ=";
            "36.0.2" = "1a0ni1a3dbv2dvh6gx2i54z8v5j9m6asqg97kkv7gqb1ivihsbp8";
            "37.0.2" = "sha256-qvrxvneoBXjP96AnUPyrtfmCnZo+IriHR5HbtWQ5Gk8=";
            "37.0.4" = "sha256-f8r6QclTwkgK20CNe9i65ZOqvSUeDc4Emv6BFBhh1hI";
            "38.0.1" = "sha256-o8l13fnfEUvUdDasq3LxSPArozRHKVsZfQg9DNR6M6Q=";
            "38.0.3" = "sha256-lzHLW1N4hZj+nn08NZiPVM/X+SEcIsuZDjEOy0OOkSc=";
            "38.0.4" = "sha256-BN0kOblUwgHj5QBf52RY2Jx0nBn03lwoN1O5PEohbwY=";
            "39.0.0" = "sha256-clorC0NtGukpE3DnZ84MSdGhJN+qC89DZPITZFuL01Q=";
            "39.0.2" = "sha256-Admz48/GS2t8diz611Ciin1HKQEyMDEwHxTpJ5tZ1ZA=";
            "40.0.0" = "sha256-/TBANavYria9YrBpMgjtFyqg5feBcloETcYJ8fdBgkI=";
            "40.0.1" = "sha256-gFfDTc2QWBWHBCycVH1dYlCsWQMVcRZfOBIau+njtDU=";
            "40.0.2" = "sha256-cV4GTfbVYanElXOVmynvrru2wJuWvnT1Z1tQKXdkbg0=";
            "41.0.1" = "sha256-38q81vRf8QHR8lFRM2KbH7Ng5nY7nmtWRMoPWS9VO/U=";
            "41.0.2" = "sha256-hkuoICa/suMXlr4u95JbMlFzi27lJqJRmWnX3nZfzKU=";
            "41.0.3" = "sha256-LQu7waympGUs+CZun2yDQd2gUUAgyisKBG5mddrfSo0=";
            "41.0.4" = "sha256-oXR8yBUgiA9BOfkZKBJneKWlpwHB71t/74b/5WpiKmw=";
            "41.0.5" = "sha256-ABCK144//RUJ3AksFHEgqC+kHvoHl1ifpVuqMTkGNH8=";
            "41.0.6" = "sha256-E7O0035BnJfTQeZNAN3Oz0fMbfj45htvnK8AHOzfdcY=";
            "41.0.7" = "sha256-VeZhKisCPDRvmSjGNwCgJJeVj65BZ0Ge+yvXbZw86Rw=";
            "42.0.1" = "sha256-Kq/TSoI1cm9Pwg5CulNlAADmxdq0oWbgymHeMErUtcE=";
            "42.0.2" = "sha256-jw/FC5rQO77h6omtBp0Nc2oitkVbNElbkBUduyprTIc=";
            "42.0.3" = "sha256-QBZLGXdQz2WIBlAJM+yBk1QgmfF4b3G0Y1I5lZmAmtU=";
            "42.0.4" = "sha256-qaXQiF1xZvv4sNIiR2cb5TfD7oNiYdvUwcm37nh2P2M=";
            "42.0.5" = "sha256-Pw3ftpcDMfZr/w6US5fnnyPVsFSB9+BuIKazDocYjTU=";
            "42.0.6" = "sha256-q1nCn82wVfADPMYX2LCq7CpIIbMvFkqsXRYfhzGyvSg=";
            "42.0.7" = "sha256-wAup/0sI8gYVsxr/vtcA+tNkBT8wxmp68FPbOuro1E4=";
            "42.0.8" = "sha256-PgxPcFocEhnQyrsNtCN8YHiMptBmk1PUhEDQFdUR1nU=";
            "43.0.0" = "sha256-TEQy8PrIaZshiBFTqR/OJp3e/bVM1USjcmpDYcjPJPM=";
            "43.0.1" = "sha256-wiAHM0ucR1X7GunZX8V0Jk2Hsi+dVdGgDKqcYjSdD7Q=";
            "43.0.3" = "sha256-d3Gt4VrBWk6qowwX0Epp4mc1PbySARVU9YMsHYKImCs=";
            "44.0.0" = "sha256-LJIY2O8ul36JQmhiW8VhLCQ0BaX+j+HGr3e8RUkZpc8=";
            "44.0.1" = "sha256-6inZ5HEnQmW5U+H+QG5eRHHdnYYnUQPXNvx6iBGXlOk=";
            "44.0.2" = "sha256-A3A9IiwcqZGSxpChsWuCquG1DNgiOzayWp43DY3lMXc=";
            "44.0.3" = "sha256-KLM+HQ0tWnHkcCcUZ9BJGnQuGVWbtjQRmcpKzgUPIvk=";
            "45.0.1" = "sha256-+3/uzwIp8daCL79jx4LM+iAoKd9YD7hUPXxuzVmpJhA=";
            "45.0.2" = "sha256-7+CEbkFTc5P8tIv5uEAv5aVzDsM2PZx+jSDCrSe5qHA=";
            "45.0.3" = "sha256-NXYN2Iln4rPkmSApQD9VcLqczefOKhiwS5uF6s8Sf5E=";
            "45.0.4" = "sha256-bLkTRQTf3VpCg9gZsFW21icH+s3e2VM/EVbiNsVT4SU=";
          }.${version} or (
            lib.warn "Unknown cryptography version: '${version}'. Please update getCargoHash." lib.fakeHash
          );
          sha256 = getCargoHash prev.cryptography.version;
          isWheel = lib.hasSuffix ".whl" prev.cryptography.src;
          scrypto =
            if isWheel then
              (
                prev.cryptography.overridePythonAttrs { preferWheel = true; }
              ) else prev.cryptography;
        in
        scrypto.overridePythonAttrs
          (
            old: {
              nativeBuildInputs = old.nativeBuildInputs or [ ]
                ++ lib.optionals (lib.versionAtLeast old.version "3.4") [ final.setuptools-rust ]
                ++ lib.optionals (!final.isPyPy) [ pyBuildPackages.cffi ]
                ++ lib.optionals (lib.versionAtLeast old.version "3.5" && !isWheel) [ pkgs.rustPlatform.cargoSetupHook pkgs.cargo pkgs.rustc ]
                ++ lib.optionals (lib.versionAtLeast old.version "43" && !isWheel) [ pkgs.rustPlatform.maturinBuildHook ]
                ++ [ pkg-config ]
              ;
              buildInputs = old.buildInputs or [ ]
                ++ [ pkgs.libxcrypt ]
                ++ [ (if lib.versionAtLeast old.version "37" then pkgs.openssl_3 else pkgs.openssl_1_1) ]
                ++ lib.optionals stdenv.isDarwin [ pkgs.darwin.apple_sdk.frameworks.Security pkgs.libiconv ];
              propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.cffi ];
            } // lib.optionalAttrs (lib.versionAtLeast old.version "3.4" && lib.versionOlder old.version "3.5") {
              CRYPTOGRAPHY_DONT_BUILD_RUST = "1";
            } // lib.optionalAttrs (lib.versionAtLeast old.version "3.5" && !isWheel) rec {
              cargoDeps =
                pkgs.rustPlatform.fetchCargoTarball {
                  inherit (old) src;
                  sourceRoot = "${old.pname}-${old.version}/${cargoRoot}";
                  name = "${old.pname}-${old.version}";
                  inherit sha256;
                };
              cargoRoot = if lib.versionAtLeast old.version "44" then "." else "src/rust";
            }
          );

      cupy-cuda12x = prev.cupy-cuda12x.overridePythonAttrs (_attrs: {
        autoPatchelfIgnoreMissingDeps = true;
      });

      cyclonedx-python-lib = prev.cyclonedx-python-lib.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
        postPatch = ''
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-warn 'setuptools>=50.3.2,<51.0.0' 'setuptools'
          fi
        '';
      });

      cysystemd = prev.cysystemd.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.systemd ];
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
      });

      daphne = prev.daphne.overridePythonAttrs (_old: {
        postPatch = ''
          # sometimes setup.py doesn't exist
          if [ -f setup.py ]; then
            substituteInPlace setup.py --replace-warn 'setup_requires=["pytest-runner"],' ""
          fi
        '';
      });

      darts = prev.darts.override {
        preferWheel = true;
      };

      dask = prev.dask.overridePythonAttrs (
        old: {
          propagatedBuildInputs = removePackagesByName
            old.propagatedBuildInputs or [ ]
            (
              # dask[dataframe] depends on dask-expr, which depends on dask, resulting in infinite recursion
              lib.optionals (final ? dask-expr) [ final.dask-expr ] ++
              # dask[dataframe] depends on distributed, which depends on dask, resulting in infinite recursion
              lib.optionals (final ? distributed) [ final.distributed ]
            );
        }
      );

      datadog-lambda = prev.datadog-lambda.overridePythonAttrs (old: {
        postPatch = ''
          substituteInPlace setup.py --replace-warn "setuptools==" "setuptools>="
        '';
        buildInputs = old.buildInputs or [ ] ++ [ final.setuptools ];
      });

      databricks-connect = prev.databricks-connect.overridePythonAttrs (_old: {
        sourceRoot = ".";
      });

      dbt-extractor = prev.dbt-extractor.overridePythonAttrs
        (
          old: {
            nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.cargo pkgs.rustc pkgs.maturin ];
          }
        );

      dbus-python = prev.dbus-python.overridePythonAttrs (old: {
        outputs = [ "out" "dev" ];
        nativeBuildInputs = old.nativeBuildInputs or [ ]
          ++ lib.optionals (lib.versionAtLeast old.version "1.3") [ pkgs.dbus ];
      } // lib.optionalAttrs (lib.versionOlder old.version "1.3") {
        postPatch = old.postPatch or "" + ''
          substituteInPlace ./configure --replace-warn /usr/bin/file ${pkgs.file}/bin/file
          substituteInPlace ./dbus-python.pc.in --replace-warn 'Cflags: -I''${includedir}' 'Cflags: -I''${includedir}/dbus-1.0'
        '';

        configureFlags = old.configureFlags or [ ] ++ [
          "PYTHON_VERSION=${lib.versions.major final.python.version}"
        ];

        preConfigure = old.preConfigure or "" + lib.optionalString
          (lib.versionAtLeast stdenv.hostPlatform.darwinMinVersion "11" && stdenv.isDarwin)
          "MACOSX_DEPLOYMENT_TARGET=10.16";

        preBuild = old.preBuild or "" + "make distclean";

        preInstall = old.preInstall or "" + "mkdir -p $out/${final.python.sitePackages}";

        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.dbus pkgs.dbus-glib ]
          # My guess why it's sometimes trying to -lncurses.
          # It seems not to retain the dependency anyway.
          ++ lib.optionals (! final.python ? modules) [ pkgs.ncurses ];
      });

      dcli = prev.dcli.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
      });

      ddtrace = prev.ddtrace.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++
          lib.optionals pkgs.stdenv.isDarwin [ pkgs.darwin.IOKit ];
      });

      deepspeed = prev.deepspeed.overridePythonAttrs (old: rec {
        CUDA_HOME = pkgs.symlinkJoin {
          name = "deepspeed-cuda-home";
          paths = [
            pkgs.cudaPackages.libnvjitlink
            pkgs.cudaPackages.libcufft
            pkgs.cudaPackages.libcusparse
            pkgs.cudaPackages.cuda_nvcc
          ];
        };
        buildInputs = old.buildInputs or [ ] ++ [ final.setuptools ];
        LD_LIBRARY_PATH = "${CUDA_HOME}/lib";
        preBuild = ''
          # Prevent the build from trying to access the default triton cache directory under /homeless-shelter
          export TRITON_CACHE_DIR=$TMPDIR
        '';
      });

      dictdiffer = prev.dictdiffer.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
        }
      );

      django = prev.django.overridePythonAttrs (
        old: {
          propagatedNativeBuildInputs = old.propagatedNativeBuildInputs or [ ]
            ++ [ pkgs.gettext final.pytest-runner ];
        }
      );

      django-bakery = prev.django-bakery.overridePythonAttrs (
        old: {
          configurePhase = ''
            if ! test -e LICENSE; then
              touch LICENSE
            fi
          '' + (old.configurePhase or "");
        }
      );

      django-cors-headers = prev.django-cors-headers.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      django-hijack = prev.django-hijack.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      django-prometheus = prev.django-prometheus.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      django-rosetta = prev.django-rosetta.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      django-stubs-ext = prev.django-stubs-ext.overridePythonAttrs (
        old: {
          prePatch = (old.prePatch or "") + "touch ../LICENSE.txt";
        }
      );

      dlib = prev.dlib.overridePythonAttrs (
        old: {
          # Parallel building enabled
          inherit (pkgs.python.pkgs.dlib) patches;

          enableParallelBuilding = true;
          dontUseCmakeConfigure = true;

          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ pkgs.dlib.nativeBuildInputs;
          buildInputs = old.buildInputs or [ ] ++ pkgs.dlib.buildInputs;
        }
      );

      # Setuptools >= 60 broke build_py_2to3
      docutils = prev.docutils.overridePythonAttrs (
        _: lib.optionalAttrs (lib.versionOlder prev.docutils.version "0.16" && lib.versionAtLeast prev.setuptools.version "60") {
          SETUPTOOLS_USE_DISTUTILS = "stdlib";
        }
      );

      duckdb = prev.duckdb.overridePythonAttrs (old: {
        postPatch = lib.optionalString (!(old.src.isWheel or false)) ''
          ${lib.optionalString (lib.versionOlder old.version "0.8") "cd tools/pythonpkg"}

          substituteInPlace setup.py \
            --replace-warn 'multiprocessing.cpu_count()' "$NIX_BUILD_CORES" \
            --replace-warn 'setuptools_scm<7.0.0' 'setuptools_scm'
        '';
      });

      # Environment markers are not always included (depending on how a dep was defined)
      enum34 = if final.pythonAtLeast "3.4" then null else prev.enum34;

      eth-hash = prev.eth-hash.overridePythonAttrs {
        preConfigure = ''
          substituteInPlace setup.py --replace-warn \'setuptools-markdown\' ""
        '';
      };

      eth-keyfile = prev.eth-keyfile.overridePythonAttrs (old: {
        preConfigure = ''
          substituteInPlace setup.py --replace-warn \'setuptools-markdown\' ""
        '';

        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
      });

      eth-keys = prev.eth-keys.overridePythonAttrs {
        preConfigure = ''
          substituteInPlace setup.py --replace-warn \'setuptools-markdown\' ""
        '';
      };

      evdev = prev.evdev.overridePythonAttrs (_old: {
        preConfigure = ''
          substituteInPlace setup.py --replace-warn /usr/include/linux ${pkgs.linuxHeaders}/include/linux
        '';
      });

      faker = prev.faker.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
          doCheck = false;
        }
      );

      fancycompleter = prev.fancycompleter.overridePythonAttrs (
        old: {
          postPatch = lib.optionalString (!(old.src.isWheel or false)) ''
            substituteInPlace setup.py \
              --replace-warn 'setup_requires="setupmeta"' 'setup_requires=[]' \
              --replace-warn 'versioning="devcommit"' 'version="${old.version}"'
          '';
        }
      );

      fastapi = prev.fastapi.overridePythonAttrs (old: {
        # fastapi 0.111 depends on fastapi-cli, which depends on fastapi, resulting in infinite recursion
        propagatedBuildInputs = removePackagesByName
          (old.propagatedBuildInputs or [ ])
          (lib.optionals (final ? fastapi-cli) [ final.fastapi-cli ]);
      });

      fastecdsa = prev.fastecdsa.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.gmp.dev ];
      });

      fastparquet = prev.fastparquet.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      file-magic = prev.file-magic.overridePythonAttrs (_: {
        postPatch = ''
          substituteInPlace magic.py \
            --replace-warn \
            "find_library('magic')" \
            "'${pkgs.file}/lib/libmagic${sharedLibExt}'"
        '';
      });

      fiona = prev.fiona.overridePythonAttrs (
        old: {
          format = lib.optionalString (!(old.src.isWheel or false)) "setuptools";
          buildInputs = old.buildInputs or [ ] ++ [ gdal ];
          nativeBuildInputs = old.nativeBuildInputs or [ ]
            ++ lib.optionals ((old.src.isWheel or false) && (!pkgs.stdenv.isDarwin)) [ pkgs.autoPatchelfHook ]
            # for gdal-config
            ++ [ gdal ];
        }
      );

      flatbuffers = prev.flatbuffers.overrideAttrs (old: {
        VERSION = old.version;
      });

      gdal = prev.gdal.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ gdal final.numpy ];
          preBuild = (old.preBuild or "") + ''
            substituteInPlace setup.cfg \
              --replace-warn "../../apps/gdal-config" '${gdal}/bin/gdal-config'
          '';
        }
      );

      gdstk = prev.gdstk.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ final.setuptools pkgs.zlib pkgs.qhull ];
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ cmake ];
        dontUseCmakeConfigure = true;
        # gdstk ships with its own FindQhull.cmake, but that isn't
        # included in the python release -- fix
        postPatch = ''
          if [ ! -e cmake_modules/FindQhull.cmake ]; then
            mkdir -p cmake_modules
            cp ${pkgs.fetchurl {
              url = "https://github.com/heitzmann/gdstk/raw/57c9ecec1f7bc2345182bcf383602a792026a28b/cmake_modules/FindQhull.cmake";
              hash = "sha256-lJNWAfSItbg7jsHfe7gZryqJruHjjMM0GXudXa/SJu4=";
            }} cmake_modules/FindQhull.cmake
          fi
        '';
      });

      gmsh = prev.gmsh.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            pkgs.libGLU
            pkgs.xorg.libXcursor
            pkgs.xorg.libXft
            pkgs.xorg.libXinerama
          ];
        }
      );

      gnureadline = prev.gnureadline.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.ncurses ];
        }
      );

      google-re2 = prev.google-re2.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.abseil-cpp final.pybind11 pkgs.re2 ];
        }
      );

      grandalf = prev.grandalf.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
          doCheck = false;
        }
      );

      granian = prev.granian.overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false))
        (
          let
            githubHash = {
              "0.2.1" = "sha256-XEhu6M1hFi3/gAKZcei7KJSrIhhlZhlvZvbfyA6VLR4=";
              "0.2.2" = "sha256-KWwefJ3CfOUGCgAm7AhFlIxRF9qxNEo3npGOxVJ23FY=";
              "0.2.3" = "sha256-2JnyO0wxkV49R/0wzDb/PnUWWHi3ckwK4nVe7dWeH1k=";
              "0.2.4" = "sha256-GdQJvVPsWgC1z7La9h11x2pRAP+L998yImhTFrFT5l8=";
              "0.2.5" = "sha256-vMXMxss77rmXSjoB53eE8XN2jXyIEf03WoQiDfvhDmw=";
              "0.2.6" = "sha256-l9W9+KDg/43mc0toEz1n1pqw+oQdiHdAxGlS+KLIGhw=";
              "0.3.0" = "sha256-icBjtW8fZjT3mLo43nKWdirMz6GZIy/RghEO95pHJEU=";
              "0.3.1" = "sha256-EKK+RxkJ//fY43EjvN1Fry7mn2ZLIaNlTyKPJRxyKZs=";
              "1.0.2" = "sha256-HOLimDGV078ZJadjywbBgpYIKR2jVk9ZAIt0kk62Va4=";
            }.${old.version} or lib.fakeHash;
            # we can count on this repo's root to have Cargo.lock

            src = pkgs.fetchFromGitHub {
              owner = "emmett-framework";
              repo = "granian";
              rev = "v${old.version}";
              sha256 = githubHash;
            };
          in
          {
            inherit src;
            cargoDeps = pkgs.rustPlatform.importCargoLock {
              lockFile = "${src.out}/Cargo.lock";
            };
            nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
              pkgs.rustPlatform.cargoSetupHook
              pkgs.rustPlatform.maturinBuildHook
            ];
          }
        ));

      gitpython = prev.gitpython.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.typing-extensions ];
        }
      );

      grpcio = prev.grpcio.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.c-ares pkgs.openssl pkgs.zlib ];

        outputs = [ "out" "dev" ];

        GRPC_BUILD_WITH_BORING_SSL_ASM = "";
        GRPC_PYTHON_BUILD_SYSTEM_OPENSSL = 1;
        GRPC_PYTHON_BUILD_SYSTEM_ZLIB = 1;
        GRPC_PYTHON_BUILD_SYSTEM_CARES = 1;
        DISABLE_LIBC_COMPATIBILITY = 1;
      });

      grpcio-tools = prev.grpcio-tools.overridePythonAttrs (_old: {
        outputs = [ "out" "dev" ];
      });

      gunicorn = prev.gunicorn.overridePythonAttrs (old: {
        # actually needs setuptools as a runtime dependency
        # 21.0.0 starts transition away from runtime dependency, starting with packaging
        propagatedBuildInputs = old.buildInputs or [ ] ++ [ final.setuptools final.packaging ];
      });

      h3 = prev.h3.overridePythonAttrs (
        old: {
          preBuild = (old.preBuild or "") + ''
            substituteInPlace h3/h3.py \
              --replace-warn "'{}/{}'.format(_dirname, libh3_path)" '"${pkgs.h3}/lib/libh3${sharedLibExt}"'
          '';
        }
      );

      h5py = prev.h5py.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) (
          let
            inherit (pkgs.hdf5) mpi mpiSupport;
          in
          {
            nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
            buildInputs =
              old.buildInputs or [ ]
              ++ [ pkgs.hdf5 pkg-config ]
              ++ lib.optionals mpiSupport [ mpi ]
            ;
            propagatedBuildInputs =
              old.propagatedBuildInputs or [ ]
              ++ lib.optionals mpiSupport [ final.mpi4py pkgs.openssh ]
            ;
            preBuild = if mpiSupport then "export CC=${mpi}/bin/mpicc" else "";
            HDF5_DIR = "${pkgs.hdf5}";
            HDF5_MPI = if mpiSupport then "ON" else "OFF";
            # avoid strict pinning of numpy
            postPatch = ''
              substituteInPlace setup.py --replace-warn "numpy ==" "numpy >="
            '';
            pythonImportsCheck = [ "h5py" ];
          }
        )
      );

      hid = prev.hid.overridePythonAttrs (
        _old: {
          postPatch = ''
            found=
            for name in libhidapi-hidraw libhidapi-libusb libhidapi-iohidmanager libhidapi; do
              full_path=${pkgs.hidapi.out}/lib/$name${sharedLibExt}
              if test -f $full_path; then
                found=t
                sed -i -e "s|'$name\..*'|'$full_path'|" hid/__init__.py
              fi
            done
            test -n "$found" || { echo "ERROR: No known libraries found in ${pkgs.hidapi.out}/lib, please update/fix this build expression."; exit 1; }
          '';
        }
      );

      hidapi = prev.hidapi.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.libusb1 ];
          postPatch = lib.optionalString stdenv.isLinux ''
            libusb=${pkgs.libusb1.dev}/include/libusb-1.0
            test -d $libusb || { echo "ERROR: $libusb doesn't exist, please update/fix this build expression."; exit 1; }
            sed -i -e "s|/usr/include/libusb-1.0|$libusb|" setup.py
          '';
        }
      );

      hikari = prev.hikari.overrideAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.setuptools ];
        }
      );

      hikari-lightbulb = prev.hikari-lightbulb.overrideAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.setuptools ];
        }
      );

      horovod = prev.horovod.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.mpi ];
        }
      );

      httplib2 = prev.httplib2.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.pyparsing ];
      });

      icecream = prev.icecream.overridePythonAttrs (_old: {
        #  # ERROR: Could not find a version that satisfies the requirement executing>=0.3.1 (from icecream) (from versions: none)
        postPatch = ''
          substituteInPlace setup.py --replace-warn 'executing>=0.3.1' 'executing'
        '';
      });

      igraph = prev.igraph.overridePythonAttrs (
        old: {
          nativeBuildInputs = [ cmake ] ++ old.nativeBuildInputs or [ ];
          dontUseCmakeConfigure = true;
        }
      );

      imagecodecs = prev.imagecodecs.overridePythonAttrs (
        old: {
          patchPhase = ''
            substituteInPlace setup.py \
              --replace-warn "/usr/include/openjpeg-2.3" \
                        "${pkgs.openjpeg.dev}/include/${pkgs.openjpeg.dev.incDir}"
            substituteInPlace setup.py \
              --replace-warn "/usr/include/jxrlib" \
                        "$out/include/libjxr"
            substituteInPlace imagecodecs/_zopfli.c \
              --replace-warn '"zopfli/zopfli.h"' \
                        '<zopfli.h>'
            substituteInPlace imagecodecs/_zopfli.c \
              --replace-warn '"zopfli/zlib_container.h"' \
                        '<zlib_container.h>'
            substituteInPlace imagecodecs/_zopfli.c \
              --replace-warn '"zopfli/gzip_container.h"' \
                        '<gzip_container.h>'
          '';

          preBuild = ''
            mkdir -p $out/include/libjxr
            ln -s ${pkgs.jxrlib}/include/libjxr/**/* $out/include/libjxr

          '';

          buildInputs = old.buildInputs or [ ] ++ [
            # Commented out packages are declared required, but not actually
            # needed to build. They are not yet packaged for nixpkgs.
            # bitshuffle
            pkgs.brotli
            # brunsli
            pkgs.bzip2
            pkgs.c-blosc
            # charls
            pkgs.giflib
            pkgs.jxrlib
            pkgs.lcms
            pkgs.libaec
            pkgs.libaec
            pkgs.libjpeg_turbo
            # liblzf
            # liblzma
            pkgs.libpng
            pkgs.libtiff
            pkgs.libwebp
            pkgs.lz4
            pkgs.openjpeg
            pkgs.snappy
            # zfp
            pkgs.zopfli
            pkgs.zstd
            pkgs.zlib
          ];
        }
      );

      # importlib-metadata has an incomplete dependency specification
      importlib-metadata = prev.importlib-metadata.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ]
            ++ lib.optionals final.python.isPy2 [ final.pathlib2 ];
        }
      );

      intreehooks = prev.intreehooks.overridePythonAttrs (
        _old: {
          doCheck = false;
        }
      );

      ipython = prev.ipython.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
        }
      );

      isort = prev.isort.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
        }
      );

      jaraco-functools = prev.jaraco-functools.overridePythonAttrs (
        old: {
          # required for the extra "toml" dependency in setuptools_scm[toml]
          buildInputs = old.buildInputs or [ ] ++ [
            final.toml
          ];
        }
      );

      trio = prev.trio.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ]
          ++ [ final.async-generator final.idna ];
      });

      jeepney = prev.jeepney.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ final.outcome final.trio ];
      });

      jinja2-ansible-filters = prev.jinja2-ansible-filters.overridePythonAttrs (
        old: {
          preBuild = (old.preBuild or "") + ''
            echo "${old.version}" > VERSION
          '';
        }
      );

      jira = prev.jira.overridePythonAttrs (
        old: {
          inherit (pkgs.python3Packages.jira) patches;
          buildInputs = old.buildInputs or [ ] ++ [
            final.pytestrunner
            final.cryptography
            final.pyjwt
          ];
        }
      );

      pyviz-comms = prev.pyviz-comms.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'setuptools>=40.8.0,<61' 'setuptools'
          '';
        }
      );

      jq = prev.jq.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.jq ];
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.certifi final.requests ];
        patches = lib.optionals (lib.versionOlder old.version "1.2.3") [
          (pkgs.fetchpatch {
            url = "https://raw.githubusercontent.com/NixOS/nixpkgs/088da8735f6620b60d724aa7db742607ea216087/pkgs/development/python-modules/jq/jq-py-setup.patch";
            sha256 = "sha256-MYvX3S1YGe0QsUtExtOtULvp++AdVrv+Fid4Jh1xewQ=";
          })
        ];
      });

      jsondiff = prev.jsondiff.overridePythonAttrs (
        old: lib.optionalAttrs (lib.versionOlder old.version "2.0.0" && !(old.src.isWheel or false)) {
          preBuild = (old.preBuild or "") + ''
            substituteInPlace setup.py --replace-warn "'jsondiff=jsondiff.cli:main_deprecated'," ""
          '';
        }
      );

      jsonslicer = prev.jsonslicer.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.yajl ];
      });

      jsonschema = prev.jsonschema.overridePythonAttrs
        (old: lib.optionalAttrs (lib.versionAtLeast old.version "4.0.0") {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.importlib-resources ];
          postPatch = old.postPatch or "" + lib.optionalString
            (!(old.src.isWheel or false) && lib.versionAtLeast old.version "4.18.0") ''
            sed -i "/Topic :: File Formats :: JSON/d" pyproject.toml
          '';
        });

      jsonschema-specifications = prev.jsonschema-specifications.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = old.postPatch or "" + ''
            sed -i "/Topic :: File Formats :: JSON/d" pyproject.toml
          '';
        }
      );

      jupyter = prev.jupyter.overridePythonAttrs (
        _old: {
          # jupyter is a meta-package. Everything relevant comes from the
          # dependencies. It does however have a jupyter.py file that conflicts
          # with jupyter-core so this meta solves this conflict.
          meta.priority = 100;
        }
      );

      jupyter-packaging = prev.jupyter-packaging.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
          final.setuptools
          final.wheel
          final.packaging
        ];
      });

      jupyter-server = prev.jupyter-server.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ final.hatch-jupyter-builder ];
      });

      nbclassic = prev.nbclassic.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.babel ];
      });

      jupyterlab-pygments = prev.jupyterlab-pygments.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          # remove the dependency cycle (why does jupyter-pygments depend on
          # jupyterlab?)
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn ', "jupyterlab~=3.1"' ""
          '';
        }
      );

      jupyterlab-widgets = prev.jupyterlab-widgets.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.jupyter-packaging ];
        }
      );

      kerberos = prev.kerberos.overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.libkrb5 ];
      });

      keyring = prev.keyring.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            final.toml
          ];
        }
      );

      kiwisolver = prev.kiwisolver.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            final.cppy
          ];
        }
      );

      lap = prev.lap.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            final.numpy
          ];
        }
      );

      libarchive = prev.libarchive.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ final.setuptools ];

        postPatch = ''
          substituteInPlace libarchive/library.py --replace-warn \
            "_FILEPATH = find_and_load_library()" "_FILEPATH = '${pkgs.libarchive.lib}/lib/libarchive${sharedLibExt}'"
        '';
      });

      libvirt-python = prev.libvirt-python.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
        propagatedBuildInputs = [ pkgs.libvirt ];
      });

      lightgbm = prev.lightgbm.overridePythonAttrs (
        old: {
          nativeBuildInputs = [ cmake ] ++ old.nativeBuildInputs or [ ];
          dontUseCmakeConfigure = true;
          postConfigure = ''
            export HOME=$(mktemp -d)
          '';
        }
      );

      license-expression = prev.license-expression.overridePythonAttrs (_old: {
        dontConfigure = true;
      });

      llama-cpp-python = prev.llama-cpp-python.overridePythonAttrs (
        old: {
          buildInputs = with pkgs; lib.optionals stdenv.isDarwin [
            darwin.apple_sdk.frameworks.Accelerate
          ];
          nativeBuildInputs = [ cmake ] ++ old.nativeBuildInputs or [ ];
          preBuild = ''
            cd "$OLDPWD"
          '';
        }
      );

      llama-index = prev.llama-index.overridePythonAttrs (_old: {
        postInstall = ''
          # Conflicts with same file from `llama-index-cli`
          rm -f $out/bin/llamaindex-cli
        '';
      });

      llvmlite = prev.llvmlite.overridePythonAttrs (
        old:
        let
          # see https://github.com/numba/llvmlite#compatibility
          llvm_version = toString (
            if lib.versionAtLeast old.version "0.40.0" then 14
            else if lib.versionAtLeast old.version "0.37.0" then 11
            else if lib.versionAtLeast old.version "0.34.0" && !stdenv.buildPlatform.isAarch64 then 10
            else if lib.versionAtLeast old.version "0.33.0" then 9
            else if lib.versionAtLeast old.version "0.29.0" then 8
            else if lib.versionAtLeast old.version "0.27.0" then 7
            else if lib.versionAtLeast old.version "0.23.0" then 6
            else if lib.versionAtLeast old.version "0.21.0" then 5
            else 4
          );
          llvm = pkgs."llvmPackages_${llvm_version}".llvm or (throw "LLVM${llvm_version} has been removed from nixpkgs; upgrade llvmlite or use older nixpkgs");
        in
        lib.optionalAttrs (!(old.src.isWheel or false)) {
          inherit llvm;
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.llvmlite.llvm ];

          # Static linking
          # https://github.com/numba/llvmlite/issues/93
          # was disabled by default in
          # https://github.com/numba/llvmlite/pull/250

          # Set directory containing llvm-config binary
          preConfigure = ''
            export LLVM_CONFIG=${llvm.dev}/bin/llvm-config
          '';

          __impureHostDeps = lib.optionals pkgs.stdenv.isDarwin [ "/usr/lib/libm.dylib" ];

          passthru = old.passthru // { inherit llvm; };
        }
      );

      lsassy = prev.lsassy.overridePythonAttrs (
        old: lib.optionalAttrs (old.version == "3.1.1") {
          # pyproject.toml contains a constraint `rich = "^10.6.0"` which is not replicated in setup.py
          # hence pypi misses it and poetry pins rich to 11.0.0
          preConfigure = (old.preConfigure or "") + ''
            rm pyproject.toml
          '';
        }
      );

      lxml = prev.lxml.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          nativeBuildInputs = with pkgs.buildPackages;
            old.nativeBuildInputs or [ ]
            ++ [ pkg-config libxml2.dev libxslt.dev ]
            ++ lib.optionals stdenv.isDarwin [ xcodebuild ];
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.libxml2 pkgs.libxslt pkgs.zlib ];
        }
      );

      m2crypto = prev.m2crypto.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ swig ];
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.openssl ];
        }
      );

      mariadb = prev.mariadb.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config pkgs.libmysqlclient ];
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.libmysqlclient ];
        }
      );

      markdown-it-py = prev.markdown-it-py.overridePythonAttrs (
        old: {
          propagatedBuildInputs = builtins.filter (i: i.pname != "mdit-py-plugins") old.propagatedBuildInputs;
          preConfigure = lib.optionalString (!(old.src.isWheel or false)) (
            (old.preConfigure or "") + ''
              substituteInPlace pyproject.toml --replace-warn 'plugins = ["mdit-py-plugins"]' 'plugins = []'
            ''
          );
        }
      );

      markupsafe = prev.markupsafe.overridePythonAttrs (
        old: {
          src = old.src.override { pname = builtins.replaceStrings [ "markupsafe" ] [ "MarkupSafe" ] old.pname; };
        }
      );

      matplotlib = prev.matplotlib.overridePythonAttrs (
        old:
        let
          enableGhostscript = old.passthru.args.enableGhostscript or false;
          enableGtk3 = old.passthru.args.enableGtk3 or false;
          enableQt = old.passthru.args.enableQt or false;
          enableTk = old.passthru.args.enableTk or false;

          interactive = enableTk || enableGtk3 || enableQt;

          passthru = {
            config = {
              directories = { basedirlist = "."; };
              libs = {
                system_freetype = true;
                system_qhull = true;
              } // lib.optionalAttrs stdenv.isDarwin {
                # LTO not working in darwin stdenv, see Nixpkgs #19312
                enable_lto = false;
              };
            };
          };

          inherit (pkgs) tk tcl wayland qhull;
          inherit (pkgs.xorg) libX11;
          inherit (pkgs.darwin.apple_sdk.frameworks) Cocoa;
          mpl39 = lib.versionAtLeast prev.matplotlib.version "3.9.0";
          isSrc = !(old.src.isWheel or false);
        in
        {
          XDG_RUNTIME_DIR = "/tmp";

          buildInputs = old.buildInputs or [ ] ++ [
            pkgs.which
          ] ++ lib.optionals enableGhostscript [
            pkgs.ghostscript
          ] ++ lib.optionals stdenv.isDarwin [
            Cocoa
          ] ++ lib.optionals (lib.versionAtLeast prev.matplotlib.version "3.7.0") [
            final.pybind11
          ];

          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            final.certifi
            pkgs.libpng
            pkgs.freetype
            qhull
          ]
            ++ lib.optionals enableGtk3 [ pkgs.cairo pkgs.librsvg final.pycairo pkgs.gtk3 pkgs.gobject-introspection final.pygobject3 ]
            ++ lib.optionals enableTk [ pkgs.tcl pkgs.tk final.tkinter pkgs.libX11 ]
            ++ lib.optionals enableQt [ final.pyqt5 ];

          dontUseMesonConfigure = isSrc && mpl39;

          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];

          mesonFlags = lib.optionals (isSrc && mpl39) [
            "-Dsystem-freetype=true"
            "-Dsystem-qhull=true"
            # broken for linux in matplotlib 3.9.0
            "-Db_lto=false"
          ];

          # Clang doesn't understand -fno-strict-overflow, and matplotlib
          # builds with -Werror
          hardeningDisable = lib.optionals stdenv.isDarwin [ "strictoverflow" ];

          passthru = old.passthru or { } // passthru;

          MPLSETUPCFG = pkgs.writeText "mplsetup.cfg" (lib.generators.toINI { } passthru.config);

          # Matplotlib tries to find Tcl/Tk by opening a Tk window and asking
          # the corresponding interpreter object for its library paths. This
          # fails if `$DISPLAY` is not set. The fallback option assumes that
          # Tcl/Tk are both installed under the same path which is not true in
          # Nix. With the following patch we just hard-code these paths into
          # the install script.
          postPatch =
            let
              tcl_tk_cache = ''"${tk}/lib", "${tcl}/lib", "${lib.strings.substring 0 3 tk.version}"'';
            in
            lib.optionalString isSrc (
              lib.optionalString enableTk ''
                sed -i '/final.tcl_tk_cache = None/s|None|${tcl_tk_cache}|' setupext.py
              '' + lib.optionalString (stdenv.isLinux && interactive) ''
                # fix paths to libraries in dlopen calls (headless detection)
                substituteInPlace src/_c_internal_utils.c \
                  --replace-warn libX11.so.6 ${libX11}/lib/libX11.so.6 \
                  --replace-warn libwayland-client.so.0 ${wayland}/lib/libwayland-client.so.0
              ''
              + lib.optionalString mpl39 ''patchShebangs .''
              # avoid matplotlib trying to download dependencies
              + lib.optionalString (!mpl39) ''
                {
                  echo '[libs]'
                  echo 'system_freetype = true'
                  echo 'system_qhull = true'
                } > mplsetup.cfg
              ''
            );
        }
      );

      mccabe = prev.mccabe.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
          doCheck = false;
        }
      );

      mip = prev.mip.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.autoPatchelfHook ];

          buildInputs = old.buildInputs or [ ] ++ [ pkgs.zlib final.cppy ];
        }
      );

      mmdet = prev.mmdet.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytorch ];
        }
      );

      molecule = prev.molecule.overridePythonAttrs (
        old: lib.optionalAttrs (lib.versionOlder old.version "3.0.0") {
          patches = old.patches or [ ] ++ [
            # Fix build with more recent setuptools versions
            (pkgs.fetchpatch {
              url = "https://github.com/ansible-community/molecule/commit/c9fee498646a702c77b5aecf6497cff324acd056.patch";
              sha256 = "1g1n45izdz0a3c9akgxx14zhdw6c3dkb48j8pq64n82fa6ndl1b7";
              excludes = [ "pyproject.toml" ];
            })
          ];
        }
      );

      msgpack = prev.msgpack.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'Cython~=3.0.0' 'Cython'
          '';
        }
      );

      msgspec = prev.msgspec.overridePythonAttrs (old: {
        # crash during integer serialization - see https://github.com/jcrist/msgspec/issues/730
        hardeningDisable = old.hardeningDisable or [ ] ++ [ "fortify" ];
      });

      munch = prev.munch.overridePythonAttrs (
        old: {
          # Latest version of pypi imports pkg_resources at runtime, so setuptools is needed at runtime. :(
          # They fixed this last year but never released a new version.
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
        }
      );

      mpi4py = prev.mpi4py.overridePythonAttrs (
        old:
        let
          cfg = pkgs.writeTextFile {
            name = "mpi.cfg";
            text = lib.generators.toINI
              { }
              {
                mpi = {
                  mpicc = "${lib.getDev pkgs.mpi}/bin/mpicc";
                };
              };
          };
        in
        {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.mpi ];
          enableParallelBuilding = true;
          preBuild = ''
            ln -sf ${cfg} mpi.cfg
          '';
        }
      );

      multiaddr = prev.multiaddr.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      mypy = prev.mypy.overridePythonAttrs (
        old:
        let
          # Compile mypy with mypyc, which makes mypy about 4 times faster. The compiled
          # version is also the default in the wheels on Pypi that include binaries.
          # is64bit: unfortunately the build would exhaust all possible memory on i686-linux.
          MYPY_USE_MYPYC = stdenv.buildPlatform.is64bit;

          envAttrs =
            if old ? env
            then { env = old.env // { inherit MYPY_USE_MYPYC; }; }
            else { inherit MYPY_USE_MYPYC; };
        in
        {
          buildInputs = old.buildInputs or [ ] ++ [
            final.types-typed-ast
            final.types-setuptools
          ]
          ++ lib.optionals (lib.versionAtLeast old.version "0.990") [ final.types-psutil ];

          # when testing reduce optimisation level to drastically reduce build time
          # (default is 3)
          # MYPYC_OPT_LEVEL = 1;
        } // envAttrs // lib.optionalAttrs (old.format != "wheel") {
          # FIXME: Remove patch after upstream has decided the proper solution.
          #        https://github.com/python/mypy/pull/11143
          patches = old.patches or [ ] ++ lib.optionals (lib.versionAtLeast old.version "0.900" && lib.versionOlder old.version "0.940") [
            (pkgs.fetchpatch {
              url = "https://github.com/python/mypy/commit/f1755259d54330cd087cae763cd5bbbff26e3e8a.patch";
              sha256 = "sha256-5gPahX2X6+/qUaqDQIGJGvh9lQ2EDtks2cpQutgbOHk=";
            })
          ] ++ lib.optionals (lib.versionAtLeast old.version "0.940" && lib.versionOlder old.version "0.960") [
            (pkgs.fetchpatch {
              url = "https://github.com/python/mypy/commit/e7869f05751561958b946b562093397027f6d5fa.patch";
              sha256 = "sha256-waIZ+m3tfvYE4HJ8kL6rN/C4fMjvLEe9UoPbt9mHWIM=";
            })
          ] ++ lib.optionals (lib.versionAtLeast old.version "0.960" && lib.versionOlder old.version "0.971") [
            (pkgs.fetchpatch {
              url = "https://github.com/python/mypy/commit/2004ae023b9d3628d9f09886cbbc20868aee8554.patch";
              sha256 = "sha256-y+tXvgyiECO5+66YLvaje8Bz5iPvfWNIBJcsnZ2nOdI=";
            })
          ];
        }
      );

      mysqlclient = prev.mysqlclient.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config pkgs.libmysqlclient ];
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.libmysqlclient ];
        }
      );

      numba = prev.numba.overridePythonAttrs (
        old: {
          autoPatchelfIgnoreMissingDeps = old.src.isWheel or false;
        }
      );

      netcdf4 = prev.netcdf4.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            pkgs.zlib
            pkgs.netcdf
            pkgs.hdf5
            pkgs.curl
            pkgs.libjpeg
          ];

          # Variables used to configure the build process
          USE_NCCONFIG = "0";
          HDF5_DIR = lib.getDev pkgs.hdf5;
          NETCDF4_DIR = pkgs.netcdf;
          CURL_DIR = pkgs.curl.dev;
          JPEG_DIR = pkgs.libjpeg.dev;
        }
      );

      numpy = prev.numpy.overridePythonAttrs (
        old:
        let
          blas = old.passthru.args.blas or pkgs.openblasCompat;
          blasImplementation = lib.nameFromURL blas.name "-";
          cfg = pkgs.writeTextFile {
            name = "site.cfg";
            text = lib.generators.toINI
              { }
              {
                ${blasImplementation} = {
                  include_dirs = "${blas}/include";
                  library_dirs = "${blas}/lib";
                } // lib.optionalAttrs (blasImplementation == "mkl") {
                  mkl_libs = "mkl_rt";
                  lapack_libs = "";
                };
              };
          };
        in
        {
          # fails to build with format=pyproject and setuptools >= 65
          format =
            if ((old.format or null) == "poetry2nix") then
              (if lib.versionAtLeast prev.numpy.version "2.0.0" then
                "pyproject"
              else "setuptools"
              )
            else
              old.format or null;
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ gfortran ];
          buildInputs = old.buildInputs or [ ] ++ [ blas ];
          enableParallelBuilding = true;
          preBuild = ''
            ln -s ${cfg} site.cfg
          '';
          preConfigure = ''
            export NPY_NUM_BUILD_JOBS=$NIX_BUILD_CORES
          '';
          passthru = old.passthru // {
            inherit blas;
            inherit blasImplementation cfg;
          };
        }
      );

      notebook = prev.notebook.overridePythonAttrs (
        old: lib.optionalAttrs (lib.versionAtLeast old.version "7.0.0") {
          buildInputs = old.buildInputs or [ ] ++ [
            prev.hatchling
            prev.hatch-jupyter-builder
          ];
          # notebook requires jlpm which is in jupyterlab
          # https://github.com/jupyterlab/jupyterlab/blob/main/jupyterlab/jlpmapp.py
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            prev.jupyterlab
          ];
        }
      );

      nvidia-cudnn-cu11 = prev.nvidia-cudnn-cu11.overridePythonAttrs (attrs: {
        propagatedBuildInputs = attrs.propagatedBuildInputs or [ ] ++ [
          final.nvidia-cublas-cu11
        ];
      });

      nvidia-cudnn-cu12 = prev.nvidia-cudnn-cu12.overridePythonAttrs (attrs: {
        propagatedBuildInputs = attrs.propagatedBuildInputs or [ ] ++ [
          final.nvidia-cublas-cu12
        ];
      });

      nvidia-cusolver-cu11 = prev.nvidia-cusolver-cu11.overridePythonAttrs (attrs: {
        propagatedBuildInputs = attrs.propagatedBuildInputs or [ ] ++ [
          final.nvidia-cublas-cu11
        ];
      });

      nvidia-cusolver-cu12 = prev.nvidia-cusolver-cu12.overridePythonAttrs (attrs: {
        propagatedBuildInputs = attrs.propagatedBuildInputs or [ ] ++ [
          final.nvidia-cublas-cu12
        ];
      });

      omegaconf = prev.omegaconf.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ jdk ];
        }
      );

      open3d = prev.open3d.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
          final.ipywidgets
        ];
        buildInputs = old.buildInputs or [ ] ++ [
          pkgs.libusb1
          pkgs.xorg.libXfixes
          pkgs.xorg.libXxf86vm
        ] ++ lib.optionals stdenv.isLinux [
          pkgs.udev
        ] ++ lib.optionals (lib.versionAtLeast prev.open3d.version "0.16.0" && !pkgs.mesa.meta.broken) [
          pkgs.mesa
        ] ++ lib.optionals (lib.versionAtLeast prev.open3d.version "0.16.0") [
          (
            pkgs.symlinkJoin {
              name = "llvm-with-ubuntu-compatible-symlink";
              paths =
                let
                  llvmVersion = "12";
                  llvmPkg = pkgs."llvm_${llvmVersion}";
                in
                [
                  llvmPkg.lib
                  (pkgs.runCommand "llvm-ubuntu-compatible-symlink" { }
                    ''
                      mkdir -p "$out/lib/";
                      ln -s "${llvmPkg.lib}/lib/libLLVM-${llvmVersion}.so" "$out/lib/libLLVM-${llvmVersion}.so.1"
                    ''
                  )
                ];
            }
          )
        ];

        # Patch the dylib in the binary distribution to point to the nix build of libomp
        preFixup = lib.optionalString (stdenv.isDarwin && lib.versionAtLeast prev.open3d.version "0.16.0") ''
          install_name_tool -change \
            /opt/homebrew/opt/libomp/lib/libomp.dylib \
            ${pkgs.llvmPackages.openmp}/lib/libomp.dylib \
            $out/lib/python*/site-packages/open3d/cpu/pybind.cpython-*-darwin.so
        '';

        # TODO(Sem Mulder): Add overridable flags for CUDA/PyTorch/Tensorflow support.
        autoPatchelfIgnoreMissingDeps = true;
      });

      openbabel-wheel = prev.openbabel-wheel.override { preferWheel = true; };

      # opencensus is a namespace package but it is distributed incorrectly
      opencensus = prev.opencensus.overridePythonAttrs (_: {
        pythonNamespaces = [
          "opencensus.common"
        ];
      });

      # opencensus is a namespace package but it is distributed incorrectly
      opencensus-context = prev.opencensus-context.overridePythonAttrs (_: {
        pythonNamespaces = [
          "opencensus.common"
        ];
      });

      # Overrides for building packages based on OpenCV
      # These flags are inspired by the opencv 4.x package in nixpkgs
      _opencv-python-override =
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          # Disable OpenCL on macOS
          # Can't use cmakeFlags because cmake is called by setup.py
          CMAKE_ARGS = lib.optionalString stdenv.isDarwin "-DWITH_OPENCL=OFF";

          nativeBuildInputs = [ cmake ] ++ old.nativeBuildInputs;
          buildInputs = [
            pkgs.ninja
          ] ++ lib.optionals stdenv.isDarwin (with pkgs.darwin.apple_sdk.frameworks; [
            Accelerate
            AVFoundation
            Cocoa
            CoreMedia
            MediaToolbox
            VideoDecodeAcceleration
          ]) ++ old.buildInputs or [ ];
          dontUseCmakeConfigure = true;
          postPatch = ''
            sed -i pyproject.toml -e 's/numpy==[0-9]\+\.[0-9]\+\.[0-9]\+;/numpy;/g'
          '';
        };

      opencv-python = prev.opencv-python.overridePythonAttrs final._opencv-python-override;

      opencv-python-headless = prev.opencv-python-headless.overridePythonAttrs final._opencv-python-override;

      opencv-contrib-python = prev.opencv-contrib-python.overridePythonAttrs final._opencv-python-override;

      openexr = prev.openexr.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.openexr pkgs.ilmbase ];
          NIX_CFLAGS_COMPILE = [ "-I${pkgs.openexr.dev}/include/OpenEXR" "-I${pkgs.ilmbase.dev}/include/OpenEXR" ];
        }
      );

      openvino = prev.openvino.overridePythonAttrs (
        old: {
          buildInputs = [
            pkgs.ocl-icd
            pkgs.hwloc
            pkgs.tbb
            pkgs.numactl
            pkgs.libxml2
          ] ++ old.buildInputs or [ ];
        }
      );

      open-clip-torch = prev.open-clip-torch.overridePythonAttrs (
        # The sdist from pypi doesn't contain the requirements.txt
        old:
        lib.optionalAttrs (!(old.src.isWheel or false)) (
          let
            githubHash =
              {
                "2.20.0" = "sha256-Ca4oi2LqleIFAGBJB7YIi4nXe2XhOP6ErDFXgXtJLxM=";
              }.${old.version} or lib.fakeHash;

            src = pkgs.fetchFromGitHub {
              owner = "mlfoundations";
              repo = "open_clip";
              rev = "v${old.version}";
              sha256 = githubHash;
            };
          in
          {
            inherit src;
          }
        )
      );

      orjson = prev.orjson.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) (
          let
            githubHash = {
              "3.10.7" = "sha256-+ofDblSbaG8CjRXFfF0QFpq2yGmLF/2yILqk2m8PSl8=";
              "3.10.6" = "sha256-K3wCzwaGOsaiCm2LW4Oc4XOnp6agrdTxCxqEIMq0fuU=";
              "3.10.5" = "sha256-Q2zi3mNgCFrg7Ucana0+lmR9C9kkuUidEJj8GneR2W4=";
              "3.10.4" = "sha256-iSTEPgtmT99RSWbrNdWQvw0u/NUsQgNq2cUnNLwvWa4=";
              "3.10.3" = "sha256-bK6wA8P/IXEbiuJAx7psd0nUUKjR1jX4scFfJr1MBAk=";
              "3.9.10" = "sha256-MkcuayNDt7/GcswXoFTvzuaZzhQEQV+V7OfKqgJwVIQ=";
              "3.9.7" = "sha256-VkCwvksUtgvFLSMy2fHLxrpZjcWYhincSM4fX/Gwl0I=";
              "3.9.5" = "sha256-OFtaHZa7wUrUxhM8DkaqAP3dYZJdFGrz1jOtCIGsbbY=";
              "3.9.1" = "sha256-4aMVYwsLYjA8yoKiauMHBEi2cMN6MQla4sK92gLfx3k=";
              "3.9.0" = "sha256-nLRluFt6dErLJUJ4W64G9o8qLTL1IKNKVtNqpN9YUNU=";
              "3.8.14" = "sha256-/1NcXGYOjCIVsFee7qgmCjnYPJnDEtyHMKJ5sBamhWE=";
              "3.8.13" = "sha256-pIxhev7Ap6r0UVYeOra/YAtbjTjn72JodhdCZIbA6lU=";
              "3.8.12" = "sha256-/1NcXGYOjCIVsFee7qgmCjnYPJnDEtyHMKJ5sBamhWE=";
              "3.8.11" = "sha256-TFoagWUtd/nJceNaptgPp4aTR/tBCmxpiZIVJwOlia4=";
              "3.8.10" = "sha256-XhOJAsF9HbyyKMU9o/f9Zl3+qYozk8tVQU8bkbXGAZs=";
              "3.8.9" = "sha256-0/yvXXj+z2jBEAGxO4BxMnx1zqUoultYSYfSkKs+hKY=";
              "3.8.8" = "sha256-pRB4QhxJh4JCDWWyp0BH25x8MRn+WieQo/dvB1mQR40=";
              "3.8.7" = "sha256-9nBgMcAfG4DTlv41gwQImwyhYm06QeiE/G4ObcLb7wU=";
              "3.8.6" = "sha256-LwLuMcnAubO7U1/KSe6tHaSP9+bi6gDfvGobixzL2gM=";
              "3.8.5" = "sha256-RG2i8QuWu2/j5jeUp6iZzVw+ciJIzQI88rLxRy6knDg=";
              "3.8.4" = "sha256-XQBiE8hmLC/AIRt0eJri/ilPHUEYiOxd0onRBQsx+pM=";
              "3.8.3" = "sha256-4rBXb4+eAaRfbl2PWZL4I01F0GvbSNqBVtU4L/sXrVc=";
            }.${old.version} or lib.fakeHash;
            # we can count on this repo's root to have Cargo.lock

            src = pkgs.fetchFromGitHub {
              owner = "ijl";
              repo = "orjson";
              rev = old.version;
              sha256 = githubHash;
            };

            cargoHash = {
              "3.10.7" = "sha256-MACmdptHmnifBTfB5s+CY6npAOFIrh0zvrIImYghGsw=";
              "3.10.6" = "sha256-SNdwqb47dJ084TMNsm2Btks1UCDerjSmSrQQUiGbx50=";
              "3.10.5" = "sha256-yhLKw4BhdIHgcu4iVlXQlHk/8J+3NK6LlmSWbm/5y4Q=";
              "3.10.4" = "sha256-3///vbnCUeMVi2Yej8IR3ensQntA+E0su0GxhMN+2Rs=";
              "3.10.3" = "sha256-ilGq+/gPSuNwURUWy2ZxInzmUv+PxYMxd8esxrMpr2o=";
              "3.9.10" = "sha256-2eRV+oZQvsWWJ4AUTeuE0CHtTHC6jNZiX/y5uXuwvns=";
              "3.9.7" = "sha256-IwWbd7LE/t1UEo/bdC0bXl2K8hYyvDPbyHLBIurfb/8=";
              "3.9.5" = "sha256-ErKqQXuSWUr3wav3SE6YpkCma3DLlV8VOsCjtvTf13M=";
              "3.9.1" = "sha256-2eRV+oZQvsWWJ4AUTeuE0CHtTHC6jNZiX/y5uXuwvns=";
              "3.9.0" = "sha256-BsRs7noHkpa74pVw5X1t+gA35XrJRBI33XYQIzXEtXA=";
              "3.8.14" = "sha256-PTfwnQW4q9StMuLwy3yB14U8uRhKRe6n/hwpHCAYB3A=";
              "3.8.13" = "sha256-L3qei2Qh1AXbfiZ0zh3CZ0HE8EYxFqp3xmw8g2TutXE=";
              "3.8.12" = "sha256-OAF1qyHLy8c1o7FNKMwzuumq1bA7x1mFzSAS/Ml7M34=";
              "3.8.11" = "sha256-/x+0/I3WFxPwVu2LliTgr42SuJX7VjOLe/SGai5OgAw=";
              "3.8.10" = "sha256-AcrTEHv7GYtGe4fXYsM24ElrzfhnOxLYlaon1ZrlD4A=";
              "3.8.9" = "sha256-ogkTRRykLF2dTOxilsfwsRH+Au/O0e1kL1e9sFOFLeY=";
              "3.8.8" = "sha256-AK4HtqPKg2O2FeLHCbY9o+N1BV4QFMNaHVE1NaFYHa4=";
              "3.8.7" = "sha256-JBO8nl0sC+XIn17vI7hC8+nA1HYI9jfvZrl9nCE3k1s=";
              "3.8.6" = "sha256-8T//q6nQoZhh8oJWDCeQf3gYRew58dXAaxkYELY4CJM=";
              "3.8.5" = "sha256-JtUCJ3TP9EKGcddeyW1e/72k21uKneq9SnZJeLvn9Os=";
              "3.8.4" = "sha256-O2W9zO7qHWG+78T+uECICAmecaSIbTTJPktJIPZYElE=";
              "3.8.3" = "sha256-oSZO4cN1sJKd0T7pYrKG63is8AZMKaLRZqj5UCVY/14=";
            }.${old.version};

          in
          {
            inherit src;
            cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
              inherit src;
              name = "${old.pname}-${old.version}";
              sha256 = cargoHash;
            };
            nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
              pkgs.rustPlatform.cargoSetupHook # handles `importCargoLock`
              pkgs.rustPlatform.maturinBuildHook # orjson is based on maturin
            ];
            buildInputs = old.buildInputs or [ ] ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];
          }
        )
      );

      osqp = prev.osqp.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ cmake ];
          dontUseCmakeConfigure = true;
        }
      );


      pandas = prev.pandas.overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
        buildInputs = old.buildInputs or [ ] ++ lib.optionals stdenv.isDarwin [ pkgs.libcxx ];

        dontUseMesonConfigure = true;

        # Doesn't work with -Werror,-Wunused-command-line-argument
        # https://github.com/NixOS/nixpkgs/issues/39687
        hardeningDisable = lib.optionals stdenv.cc.isClang [ "strictoverflow" ];

        # For OSX, we need to add a dependency on libcxx, which provides
        # `complex.h` and other libraries that pandas depends on to build.
        postPatch = ''
          if [ -f pyproject.toml ]; then
            substituteInPlace pyproject.toml \
              --replace-warn 'meson-python==0.13.1' 'meson-python'
          fi
        '' + lib.optionalString (!(old.src.isWheel or false) && stdenv.isDarwin) ''
          if [ -f setup.py ]; then
            cpp_sdk="${lib.getDev pkgs.libcxx}/include/c++/v1";
            echo "Adding $cpp_sdk to the setup.py common_include variable"
            substituteInPlace setup.py \
              --replace-warn "['pandas/src/klib', 'pandas/src']" \
                        "['pandas/src/klib', 'pandas/src', '$cpp_sdk']"
          fi
        '';

        enableParallelBuilding = true;
      });

      pantalaimon = prev.pantalaimon.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.installShellFiles ];
        postInstall = old.postInstall or "" + ''
          installManPage docs/man/*.[1-9]
        '';
      });

      pao = prev.pao.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.pyutilib ];
      });

      paramiko = prev.paramiko.overridePythonAttrs (old: {
        doCheck = false; # requires networking

        optional-dependencies = old.optional-dependencies or {
          ed25519 = [
            final.pynacl
            final.bcrypt
          ];
        };
      });

      parsel = prev.parsel.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      pdal = prev.pdal.overridePythonAttrs (
        _old: {
          PDAL_CONFIG = "${pkgs.pdal}/bin/pdal-config";
        }
      );

      peewee = prev.peewee.overridePythonAttrs (
        old:
        let
          withPostgres = old.passthru.withPostgres or false;
          withMysql = old.passthru.withMysql or false;
        in
        {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.sqlite ];
          propagatedBuildInputs = old.propagatedBuildInputs or [ ]
            ++ lib.optionals withPostgres [ final.psycopg2 ]
            ++ lib.optionals withMysql [ final.mysql-connector ];
        }
      );

      pendulum = prev.pendulum.overridePythonAttrs (
        old:
        # NOTE: Versions <3.0.0 is pure Python and is not PEP-517 compliant,
        #       which means they can not be built using recent Poetry versions.
        lib.optionalAttrs (lib.versionAtLeast old.version "3" && (!old.src.isWheel or false)) {
          cargoRoot = "rust";
          cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = ./pendulum/3.0.0-Cargo.lock;
          };
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            pkgs.rustPlatform.cargoSetupHook
            pkgs.rustPlatform.maturinBuildHook
          ];
          buildInputs = old.buildInputs or [ ] ++ lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
          ];
        }
      );

      phonetics = prev.phonetics.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
      });

      pikepdf = prev.pikepdf.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.qpdf final.pybind11 ];
          pythonImportsCheck = old.pythonImportsCheck or [ ] ++ [ "pikepdf" ];
        }
      );

      pillow = prev.pillow.overridePythonAttrs (
        old:
        let
          preConfigure = (old.preConfigure or "") + pkgs.python3.pkgs.pillow.preConfigure;
        in
        {
          nativeBuildInputs = old.nativeBuildInputs or [ ]
            ++ [ pkg-config final.pytest-runner ];
          buildInputs = with pkgs; old.buildInputs or [ ]
            ++ [ freetype libjpeg zlib libtiff libxcrypt libwebp tcl lcms2 ]
            ++ lib.optionals (lib.versionAtLeast old.version "7.1.0") [ xorg.libxcb ]
            ++ lib.optionals final.isPyPy [ tk xorg.libX11 ];
          preConfigure = lib.optionals (old.format != "wheel") [ preConfigure ];

          # https://github.com/nix-community/poetry2nix/issues/1139
          patches = (old.patches or [ ]) ++ pkgs.lib.optionals (!(old.src.isWheel or false) && old.version == "9.5.0") [
            (pkgs.fetchpatch {
              url = "https://github.com/python-pillow/Pillow/commit/0ec0a89ead648793812e11739e2a5d70738c6be5.diff";
              sha256 = "sha256-rZfk+OXZU6xBpoumIW30E80gRsox/Goa3hMDxBUkTY0=";
            })
          ];
        }
      );

      pillow-avif-plugin = prev.pillow-avif-plugin.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.libavif ];
        }
      );

      pillow-heif = prev.pillow-heif.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.libheif ];
        }
      );

      pip-requirements-parser = prev.pip-requirements-parser.overridePythonAttrs (_old: {
        dontConfigure = true;
      });

      pluralizer = prev.pluralizer.overridePythonAttrs (old: {
        preBuild = ''
          export PYPI_VERSION="${old.version}"
        '';
      });

      poethepoet = prev.poethepoet.overrideAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.poetry ];
      });

      pkgutil-resolve-name = prev.pkgutil-resolve-name.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'flit_core >=2,<3' 'flit_core'
          '';
        }
      );

      plyvel = prev.plyvel.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.leveldb ];
      });

      poetry-plugin-export = prev.poetry-plugin-export.overridePythonAttrs (_old: {
        dontUsePythonImportsCheck = true;
        pipInstallFlags = [
          "--no-deps"
        ];
      });

      polling2 = prev.polling2.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      portend = prev.portend.overridePythonAttrs (
        old: {
          # required for the extra "toml" dependency in setuptools_scm[toml]
          buildInputs = old.buildInputs or [ ] ++ [
            final.toml
          ];
        }
      );

      prettytable = prev.prettytable.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
      });

      propcache = prev.propcache.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ]
          ++ lib.optionals (final.pythonOlder "3.11") [ final.tomli ];
      });

      prophet = prev.prophet.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.cmdstan final.cmdstanpy ];
        PROPHET_REPACKAGE_CMDSTAN = "false";
        CMDSTAN = "${pkgs.cmdstan}";
      });

      psycopg-c = prev.psycopg-c.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.postgresql ];
        }
      );

      psycopg2 = prev.psycopg2.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ]
            ++ lib.optionals stdenv.isDarwin [ pkgs.openssl ];
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.postgresql ];
        }
      );

      psycopg2-binary = prev.psycopg2-binary.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ]
            ++ lib.optionals stdenv.isDarwin [ pkgs.openssl ];
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.postgresql ];
        }
      );

      psycopg2cffi = prev.psycopg2cffi.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ]
            ++ lib.optionals stdenv.isDarwin [ pkgs.openssl ];
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.postgresql ];
        }
      );

      pemja = prev.pemja.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.openjdk17_headless ];
      });

      pycrdt =
        let
          hashes = {
            "0.9.11" = "sha256-qKrYCkSP8f/oQytfc1xvBX6gt26D3Z/5bbzKPO0e0tQ=";
          };
        in
        prev.pycrdt.overridePythonAttrs (old: {
          cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
            inherit (old) src;
            name = "${old.pname}-${old.version}";
            sha256 = hashes.${old.version};
          };

          buildInputs = old.buildInputs or [ ] ++ lib.optionals stdenv.isDarwin [
            pkgs.libiconv
          ];

          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            pkgs.rustPlatform.cargoSetupHook
            pkgs.rustPlatform.maturinBuildHook
          ];
        });

      pycurl = prev.pycurl.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.curl ];
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.curl ];
        }
      );

      pydantic-core = prev.pydantic-core.override {
        preferWheel = true;
      };

      py-solc-x = prev.py-solc-x.overridePythonAttrs (
        old: {
          preConfigure = ''
            substituteInPlace setup.py --replace-warn \'setuptools-markdown\' ""
          '';
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.requests final.semantic-version ];
        }
      );

      pyarrow = prev.pyarrow.overridePythonAttrs (
        old: lib.optionalAttrs ((!old.src.isWheel or false) && lib.versionAtLeast old.version "0.16.0")
          (
            let
              # Starting with nixpkgs revision f149c7030a7, pyarrow takes "python3" as an argument
              # instead of "python". Below we inspect function arguments to maintain compatibilitiy.
              _arrow-cpp = pkgs.arrow-cpp.override (
                builtins.intersectAttrs
                  (lib.functionArgs pkgs.arrow-cpp.override)
                  { inherit (final) python; python3 = final.python; }
              );

              ARROW_HOME = _arrow-cpp;
              arrowCppVersion = lib.versions.majorMinor _arrow-cpp.version;
              pyArrowVersion = lib.versions.majorMinor prev.pyarrow.version;
              errorMessage = "arrow-cpp version (${arrowCppVersion}) mismatches pyarrow version (${pyArrowVersion})";
            in
            lib.throwIf (arrowCppVersion != pyArrowVersion) errorMessage {
              nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config cmake ];

              buildInputs = old.buildInputs or [ ] ++ [
                _arrow-cpp
              ];

              preBuild = ''
                export PYARROW_PARALLEL=$NIX_BUILD_CORES
              '';

              PARQUET_HOME = _arrow-cpp;
              inherit ARROW_HOME;

              PYARROW_BUILD_TYPE = "release";
              PYARROW_WITH_FLIGHT = if _arrow-cpp.enableFlight then 1 else 0;
              PYARROW_WITH_DATASET = 1;
              PYARROW_WITH_PARQUET = 1;
              PYARROW_CMAKE_OPTIONS = [
                "-DCMAKE_INSTALL_RPATH=${ARROW_HOME}/lib"

                # This doesn't use setup hook to call cmake so we need to workaround #54606
                # ourselves
                "-DCMAKE_POLICY_DEFAULT_CMP0025=NEW"
              ];

              dontUseCmakeConfigure = true;
            }
          )
      );

      pycairo = prev.pycairo.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];

          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.cairo ];
        }
      );

      pycocotools = prev.pycocotools.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            final.numpy
          ];
        }
      );

      pyfftw = prev.pyfftw.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [
          pkgs.fftw
          pkgs.fftwFloat
          pkgs.fftwLongDouble
        ];
      });

      pyfuse3 = prev.pyfuse3.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.fuse3 ];
      });

      pygame = prev.pygame.overridePythonAttrs (
        _old: rec {
          nativeBuildInputs = [ pkg-config pkgs.SDL ];
          buildInputs = [
            pkgs.SDL
            pkgs.SDL_image
            pkgs.SDL_mixer
            pkgs.SDL_ttf
            pkgs.libpng
            pkgs.libjpeg
            pkgs.portmidi
            pkgs.xorg.libX11
            pkgs.freetype
          ];

          # Tests fail because of no audio device and display.
          doCheck = false;
          preConfigure = ''
                    sed \
                      -e "s/origincdirs = .*/origincdirs = []/" \
                      -e "s/origlibdirs = .*/origlibdirs = []/" \
                      -e "/'\/lib\/i386-linux-gnu', '\/lib\/x86_64-linux-gnu']/d" \
                      -e "/\/include\/smpeg/d" \
                      -i buildconfig/config_unix.py
                    ${lib.concatMapStrings
            (dep: ''
                      sed \
                        -e "/origincdirs =/a\        origincdirs += ['${lib.getDev dep}/include']" \
                        -e "/origlibdirs =/a\        origlibdirs += ['${lib.getLib dep}/lib']" \
                        -i buildconfig/config_unix.py
                    '')
            buildInputs
                    }
                    LOCALBASE=/ ${final.python.interpreter} buildconfig/config.py
          '';
        }
      );

      pygeos = prev.pygeos.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.geos ];
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.geos ];
        }
      );

      pygobject = prev.pygobject.overridePythonAttrs (
        old:
        let
          isWheel = old.src.isWheel or false;
        in
        {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ lib.optionals (!isWheel) [
            pkg-config
            meson
            ninja
            pkgs.gobject-introspection
            final.meson-python
          ];

          buildInputs = old.buildInputs or [ ] ++ [
            pkgs.cairo
            pkgs.glib
          ] ++ lib.optionals stdenv.isDarwin [ pkgs.ncurses ];

          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            final.pycairo
          ];

          postConfigure = lib.optionalString (!isWheel) ''
            cd ..
          '';
        }
      );

      pyinstaller = prev.pyinstaller.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.zlib ];
      });

      pymdown-extensions = prev.pymdown-extensions.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.pyyaml ];
      });

      pylint = prev.pylint.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      pymediainfo = prev.pymediainfo.overridePythonAttrs (
        old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace pymediainfo/__init__.py \
              --replace-warn "libmediainfo.0.dylib" \
                        "${pkgs.libmediainfo}/lib/libmediainfo.0${sharedLibExt}" \
              --replace-warn "libmediainfo.dylib" \
                        "${pkgs.libmediainfo}/lib/libmediainfo${sharedLibExt}" \
              --replace-warn "libmediainfo.so.0" \
                        "${pkgs.libmediainfo}/lib/libmediainfo${sharedLibExt}.0"
          '';
        }
      );

      pynetbox = prev.pynetbox.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
      });

      sphinxcontrib-applehelp = prev.sphinxcontrib-applehelp.overridePythonAttrs (old: {
        propagatedBuildInputs = removePackagesByName (old.propagatedBuildInputs or [ ]) [ final.sphinx ];
      });

      sphinxcontrib-devhelp = prev.sphinxcontrib-devhelp.overridePythonAttrs (old: {
        propagatedBuildInputs = removePackagesByName (old.propagatedBuildInputs or [ ]) [ final.sphinx ];
      });

      sphinxcontrib-htmlhelp = prev.sphinxcontrib-htmlhelp.overridePythonAttrs (old: {
        propagatedBuildInputs = removePackagesByName (old.propagatedBuildInputs or [ ]) [ final.sphinx ];
      });

      sphinxcontrib-jsmath = prev.sphinxcontrib-jsmath.overridePythonAttrs (old: {
        propagatedBuildInputs = removePackagesByName (old.propagatedBuildInputs or [ ]) [ final.sphinx ];
      });

      sphinxcontrib-jquery = prev.sphinxcontrib-jquery.overridePythonAttrs (old: {
        propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ final.sphinx ];
      });

      sphinxcontrib-qthelp = prev.sphinxcontrib-qthelp.overridePythonAttrs (old: {
        propagatedBuildInputs = removePackagesByName (old.propagatedBuildInputs or [ ]) [ final.sphinx ];
      });

      sphinxcontrib-serializinghtml = prev.sphinxcontrib-serializinghtml.overridePythonAttrs (old: {
        propagatedBuildInputs = removePackagesByName (old.propagatedBuildInputs or [ ]) [ final.sphinx ];
      });

      pynput = prev.pynput.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.sphinx ];
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools-lint ];
      });

      pymssql = prev.pymssql.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ]
          ++ [ pkgs.openssl pkgs.libkrb5 ];
        propagatedBuildInputs = old.propagatedBuildInputs or [ ]
          ++ [ pkgs.freetds ];
      });

      pyodbc = prev.pyodbc.overridePythonAttrs (
        old: lib.optionalAttrs (old.src.isWheel or false) {
          preFixup = old.preFixup or "" + lib.optionalString stdenv.isLinux ''
            addAutoPatchelfSearchPath ${pkgs.unixODBC}
          '' + lib.optionalString stdenv.isDarwin ''
            if [ -e /opt/homebrew/opt/unixodbc/lib/libodbc.2.dylib ]; then
              install_name_tool -change \
                /opt/homebrew/opt/unixodbc/lib/libodbc.2.dylib \
                ${lib.getLib pkgs.unixODBC}/lib/libodbc.2.dylib \
                $out/${final.python.sitePackages}/pyodbc.cpython-*-darwin.so
            fi
          '';
        }
      );

      pyogrio = prev.pyogrio.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ]
          ++ [ final.versioneer gdal ]
          ++ lib.optionals (final.pythonOlder "3.11") [ final.tomli ];
      });

      pyopencl = prev.pyopencl.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.numpy ];
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.ocl-icd pkgs.opencl-headers ];
        }
      );

      pyopenssl = prev.pyopenssl.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.openssl ];
        }
      );

      pyproj = prev.pyproj.overridePythonAttrs (
        _old: {
          PROJ_DIR = "${pkgs.proj}";
          PROJ_LIBDIR = "${pkgs.proj}/lib";
          PROJ_INCDIR = "${pkgs.proj.dev}/include";
        }
      );

      pyrealsense2 = prev.pyrealsense2.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.libusb1.out ];
      });

      pyrfr = prev.pyrfr.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ swig ];
      });

      pyscard = prev.pyscard.overridePythonAttrs (old:
        # see https://github.com/NixOS/nixpkgs/blob/93568862a610dc1469dc40b15c1096a9357698ac/pkgs/development/python-modules/pyscard/default.nix
        let
          inherit (pkgs) PCSC pcsclite;
          withApplePCSC = stdenv.isDarwin;
        in
        {
          postPatch =
            if withApplePCSC then ''
              substituteInPlace smartcard/scard/winscarddll.c \
                --replace-warn "/System/Library/Frameworks/PCSC.framework/PCSC" \
                          "${PCSC}/Library/Frameworks/PCSC.framework/PCSC"
            '' else ''
              substituteInPlace smartcard/scard/winscarddll.c \
                --replace-warn "libpcsclite.so.1" \
                          "${lib.getLib pcsclite}/lib/libpcsclite${sharedLibExt}"
            '';
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ (
            if withApplePCSC then [ PCSC ] else [ pcsclite ]
          );
          NIX_CFLAGS_COMPILE = lib.optionalString (! withApplePCSC)
            "-I ${lib.getDev pcsclite}/include/PCSC";
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ swig ];
        }
      );

      pytaglib = prev.pytaglib.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.taglib ];
      });

      pytesseract =
        let
          pytesseract-cmd-patch = pkgs.writeText "pytesseract-cmd.patch" ''
            --- a/pytesseract/pytesseract.py
            +++ b/pytesseract/pytesseract.py
            @@ -27,7 +27,7 @@
             from PIL import Image


            -tesseract_cmd = 'tesseract'
            +tesseract_cmd = '${pkgs.tesseract4}/bin/tesseract'

             numpy_installed = find_loader('numpy') is not None
             if numpy_installed:
          '';
        in
        prev.pytesseract.overridePythonAttrs (old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.tesseract4 ];
          patches = (old.patches or [ ]) ++ lib.optionals (!(old.src.isWheel or false)) [ pytesseract-cmd-patch ];

          # apply patch in postInstall if the source is a wheel
          postInstall = lib.optionalString (old.src.isWheel or false) ''
            pushd "$out/${final.python.sitePackages}"
            patch -p1 < "${pytesseract-cmd-patch}"
            popd
          '';
        });

      pytezos = prev.pytezos.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.libsodium ];
      });

      python-bugzilla = prev.python-bugzilla.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.docutils ];
        }
      );

      python-ldap = prev.python-ldap.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            pkgs.openldap
            pkgs.cyrus_sasl
            # Fix for "cannot find -lldap_r: No such file or directory"
            (pkgs.writeTextFile {
              name = "openldap-lib-fix";
              destination = "/lib/libldap_r.so";
              text = "INPUT ( libldap.so )\n";
            })
          ];
        }
      );

      python-snap7 = prev.python-snap7.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
          pkgs.snap7
        ];

        postPatch = (old.postPatch or "") + ''
          echo "Patching find_library call."
          substituteInPlace snap7/common.py \
            --replace-warn "find_library('snap7')" "\"${pkgs.snap7}/lib/libsnap7.so\""
        '';
      });

      pytoml = prev.pytoml.overridePythonAttrs (
        _old: {
          doCheck = false;
        }
      );

      pyqt5 =
        let
          qt5 = selectQt5 prev.pyqt5.version;
        in
        prev.pyqt5.overridePythonAttrs (
          old: {
            postPatch = ''
              # Confirm license
              sed -i s/"if tool == 'pep517':"/"if True:"/ project.py
            '';

            dontConfigure = true;
            dontWrapQtApps = true;
            nativeBuildInputs = old.nativeBuildInputs or [ ] ++ pyQt5Modules qt5 ++ [
              final.pyqt-builder
              final.sip
            ];
          }
        );

      pyqt5-qt5 =
        let
          qt5 = selectQt5 prev.pyqt5-qt5.version;
        in
        prev.pyqt5-qt5.overridePythonAttrs (
          old: {
            dontWrapQtApps = true;
            propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ pyQt5Modules qt5 ++ [
              pkgs.gtk3
              pkgs.speechd
              pkgs.postgresql
              pkgs.unixODBC
            ];
          }
        );

      pyqt6 =
        let
          pyqt6 = prev.pyqt6.overridePythonAttrs (old:
            let
              confirm-license = pkgs.writeText "confirm-license.patch" ''
                diff --git a/project.py b/project.py
                --- a/project.py
                +++ b/project.py
                @@ -163,8 +163,7 @@

                         # Automatically confirm the license if there might not be a command
                         # line option to do so.
                -        if tool == 'pep517':
                -            final.confirm_license = True
                +        final.confirm_license = True

                         final._check_license()


              '';
              isWheel = old.src.isWheel or false;
            in
            {
              propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
                final.dbus-python
              ];
              nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
                pkg-config
                final.pyqt6-sip
                final.sip
                final.pyqt-builder
                pkgs.xorg.lndir
                pkgs.qt6.qmake
              ] ++ lib.optionals isWheel [
                pkgs.qt6.full # building from source doesn't properly pick up libraries from pyqt6-qt6
              ];
              patches = lib.optionals (!isWheel) [
                confirm-license
              ];
              env.NIX_CFLAGS_COMPILE = "-fpermissive";
              # be more verbose
              postPatch = ''
                cat >> pyproject.toml <<EOF
                [tool.sip.project]
                verbose = true
                EOF
              '';
              dontWrapQtApps = true;
              dontConfigure = true;
              enableParallelBuilding = true;
              # HACK: parallelize compilation of make calls within pyqt's setup.py
              # pkgs/stdenv/generic/setup.sh doesn't set this for us because
              # make gets called by python code and not its build phase
              # format=pyproject means the pip-build-hook hook gets used to build this project
              # pkgs/development/interpreters/python/hooks/pip-build-hook.sh
              # does not use the enableParallelBuilding flag
              postUnpack = ''
                export MAKEFLAGS+="''${enableParallelBuilding:+-j$NIX_BUILD_CORES}"
              '';
              preFixup = lib.optionalString isWheel ''
                addAutoPatchelfSearchPath ${final.pyqt6-qt6}/${final.python.sitePackages}/PyQt6
              '';
            });
        in
        pyqt6;

      pyqt6-qt6 = prev.pyqt6-qt6.overridePythonAttrs (old: {
        autoPatchelfIgnoreMissingDeps = [ "libmysqlclient.so.21" "libmimerapi.so" "libQt6*" ];
        preFixup = ''
          addAutoPatchelfSearchPath $out/${final.python.sitePackages}/PyQt6/Qt6/lib
        '';
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
          pkgs.libxkbcommon
          pkgs.gtk3
          pkgs.speechd
          pkgs.gst
          pkgs.gst_all_1.gst-plugins-base
          pkgs.gst_all_1.gstreamer
          pkgs.postgresql.lib
          pkgs.unixODBC
          pkgs.pcsclite
          pkgs.xorg.libxcb
          pkgs.xorg.xcbutil
          pkgs.xorg.xcbutilcursor
          pkgs.xorg.xcbutilerrors
          pkgs.xorg.xcbutilimage
          pkgs.xorg.xcbutilkeysyms
          pkgs.xorg.xcbutilrenderutil
          pkgs.xorg.xcbutilwm
          pkgs.libdrm
          pkgs.pulseaudio
        ];
      });

      pyside6-essentials = prev.pyside6-essentials.overridePythonAttrs (old: lib.optionalAttrs stdenv.isLinux {
        autoPatchelfIgnoreMissingDeps = [ "libmysqlclient.so.21" "libmimerapi.so" "libQt6EglFsKmsGbmSupport.so*" ];
        preFixup = ''
          addAutoPatchelfSearchPath ${final.shiboken6}/${final.python.sitePackages}/shiboken6
        '';
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
          pkgs.qt6.full
          pkgs.libxkbcommon
          pkgs.gtk3
          pkgs.speechd
          pkgs.gst
          pkgs.gst_all_1.gst-plugins-base
          pkgs.gst_all_1.gstreamer
          pkgs.postgresql.lib
          pkgs.unixODBC
          pkgs.pcsclite
          pkgs.xorg.libxcb
          pkgs.xorg.xcbutil
          pkgs.xorg.xcbutilcursor
          pkgs.xorg.xcbutilerrors
          pkgs.xorg.xcbutilimage
          pkgs.xorg.xcbutilkeysyms
          pkgs.xorg.xcbutilrenderutil
          pkgs.xorg.xcbutilwm
          pkgs.libdrm
          pkgs.pulseaudio
        ];
        pythonImportsCheck = [
          "PySide6"
          "PySide6.QtCore"
        ];
        postInstall = ''
          python -c 'import PySide6; print(PySide6.__all__)'
        '';
      });

      pyside6-addons = prev.pyside6-addons.overridePythonAttrs (_old: lib.optionalAttrs stdenv.isLinux {
        autoPatchelfIgnoreMissingDeps = [
          "libmysqlclient.so.21"
          "libmimerapi.so"
        ];
        preFixup = ''
          addAutoPatchelfSearchPath ${final.shiboken6}/${final.python.sitePackages}/shiboken6
          addAutoPatchelfSearchPath ${final.pyside6-essentials}/${final.python.sitePackages}/PySide6
          addAutoPatchelfSearchPath $out/${final.python.sitePackages}/PySide6
        '';
        buildInputs = [
          pkgs.nss
          pkgs.xorg.libXtst
          pkgs.alsa-lib
          pkgs.xorg.libxshmfence
          pkgs.xorg.libxkbfile
        ];
        postInstall = ''
          rm -r $out/${final.python.sitePackages}/PySide6/__pycache__/
        '';
      });
      pyside6 = prev.pyside6.overridePythonAttrs (_old: {
        # The PySide6/__init__.py script tries to find the Qt libraries
        # relative to its own path in the installed site-packages directory.
        # This then fails to find the paths from pyside6-essentials and
        # pyside6-addons because they are installed into different directories.
        #
        # To work around this issue we symlink all of the files resulting from
        # those packages into the aggregated `pyside6` output directories.
        #
        # See https://github.com/nix-community/poetry2nix/issues/1791 for more details.
        postFixup = ''
          ${pkgs.xorg.lndir}/bin/lndir ${final.pyside6-essentials}/${final.python.sitePackages}/PySide6 $out/${final.python.sitePackages}/PySide6
          ${pkgs.xorg.lndir}/bin/lndir ${final.pyside6-addons}/${final.python.sitePackages}/PySide6 $out/${final.python.sitePackages}/PySide6
          rm -r $out/${final.python.sitePackages}/PySide6/__pycache__/
        '';
      });

      pytest-datadir = prev.pytest-datadir.overridePythonAttrs (
        _old: {
          postInstall = ''
            rm -f $out/LICENSE
          '';
        }
      );

      pytest = prev.pytest.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          # Fixes https://github.com/pytest-dev/pytest/issues/7891
          postPatch = old.postPatch or "" + ''
            # sometimes setup.cfg doesn't exist
            if [ -f setup.cfg ]; then
              sed -i '/\[metadata\]/aversion = ${old.version}' setup.cfg
            fi
          '';
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            final.toml
          ];
        }
      );

      pytest-django = prev.pytest-django.overridePythonAttrs (
        _old: {
          postPatch = ''
            # sometimes setup.py doesn't exist
            if [ -f setup.py ]; then
              substituteInPlace setup.py --replace-warn "'pytest>=3.6'," ""
              substituteInPlace setup.py --replace-warn "'pytest>=3.6'" ""
            fi
          '';
        }
      );

      pytest-randomly = prev.pytest-randomly.overrideAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
          final.importlib-metadata
        ];
      });

      pytest-mypy = prev.pytest-mypy.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'setuptools ~= 50.3.0' 'setuptools' \
              --replace-warn 'wheel ~= 0.36.0' 'wheel' \
              --replace-warn 'setuptools-scm[toml] ~= 5.0.0' 'setuptools-scm[toml]' \
          '';
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            final.toml
          ];
        }
      );

      pytest-runner = final.buildPythonPackage rec {
        pname = "pytest-runner";
        version = "6.0.1";
        pyproject = true;

        src = final.pkgs.fetchPypi {
          inherit pname version;
          hash = "sha256-cNRzlYWnAI83v0kzwBP9sye4h4paafy7MxbIiILw9Js=";
        };

        build-system = [ final.setuptools final.setuptools-scm ];
      };

      pytest-pylint = prev.pytest-pylint.overridePythonAttrs (
        _old: {
          buildInputs = [ final.pytest-runner ];
        }
      );

      # pytest-splinter seems to put a .marker file in an empty directory
      # presumably so it's tracked by and can be installed with MANIFEST.in, see
      # https://github.com/pytest-dev/pytest-splinter/commit/a48eeef662f66ff9d3772af618748e73211a186b
      #
      # This directory then gets used as an empty initial profile directory and is
      # zipped up. But if the .marker file is in the Nix store, it has the
      # creation date of 1970, and Zip doesn't work with such old files, so it
      # fails at runtime!
      #
      # We fix this here by just removing the file after the installation
      #
      # The error you get without this is:
      #
      # E           ValueError: ZIP does not support timestamps before 1980
      # /nix/store/55b9ip7xkpimaccw9pa0vacy5q94f5xa-python3-3.7.6/lib/python3.7/zipfile.py:357: ValueError
      pytest-splinter = prev.pytest-splinter.overrideAttrs (old: {
        postInstall = old.postInstall or "" + ''
          rm $out/${prev.python.sitePackages}/pytest_splinter/profiles/firefox/.marker
        '';
      });

      python-jose = prev.python-jose.overridePythonAttrs (
        _old: {
          buildInputs = [ final.pytest-runner ];
        }
      );

      python-magic = prev.python-magic.overridePythonAttrs (old:
        let
          libPath = "${lib.getLib pkgs.file}/lib/libmagic${sharedLibExt}";
          fixupScriptText = ''
            substituteInPlace magic/loader.py \
              --replace-warn "find_library('magic')" "'${libPath}'"
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

      python-olm = prev.python-olm.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.olm ];
        }
      );

      python-pam = prev.python-pam.overridePythonAttrs (
        _old: {
          postPatch = ''
            substituteInPlace src/pam/__internals.py \
            --replace-warn 'find_library("pam")' '"${pkgs.pam}/lib/libpam.so"' \
            --replace-warn 'find_library("pam_misc")' '"${pkgs.pam}/lib/libpam_misc.so"'
          '';
        }
      );

      python-snappy = prev.python-snappy.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ pkgs.snappy ];
        }
      );

      python-twitter = prev.python-twitter.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
      });

      pythran = prev.pythran.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
      });

      ffmpeg-python = prev.ffmpeg-python.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      python-prctl = prev.python-prctl.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            pkgs.libcap
          ];
        }
      );

      pyudev = prev.pyudev.overridePythonAttrs (_old: {
        postPatch = ''
          substituteInPlace src/pyudev/_ctypeslib/utils.py \
            --replace-warn "find_library(name)" "'${lib.getLib pkgs.systemd}/lib/libudev.so'"
        '';
      });

      pyusb = prev.pyusb.overridePythonAttrs (
        _old: {
          postPatch = ''
            libusb=${pkgs.libusb1.out}/lib/libusb-1.0${sharedLibExt}
            test -f $libusb || { echo "ERROR: $libusb doesn't exist, please update/fix this build expression."; exit 1; }
            sed -i -e "s|find_library=None|find_library=lambda _:\"$libusb\"|" usb/backend/libusb1.py
          '';
        }
      );

      pywavelets = prev.pywavelets.overridePythonAttrs (
        old: {
          HDF5_DIR = "${pkgs.hdf5}";
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.hdf5 ];
        }
      );
      pyyaml = prev.pyyaml.overridePythonAttrs (
        old: {
            buildInputs = old.buildInputs or [ ] ++ [ pkgs.libyaml ];
      });

      pyzmq = prev.pyzmq.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.zeromq pkgs.libsodium ];
          # setting dontUseCmakeConfigure is necessary because:
          #
          # 1. pyzmq uses scikit-build-core as of pyzmq version 26.0.0
          # 2. scikit-build-core requires the *Python* cmake package to find the cmake binary
          # 3. since scikit-build-core's is in nativeBuildInputs and python
          #    cmake depends on pkgs.cmake that puts cmake in pyzmq's
          #    nativeBuildInputs
          # 4. point 3 causes the pyzmq build it use vanilla cmake configure
          #    instead of cmake via scikit-build-core
          #
          # what a heaping mess
          dontUseCmakeConfigure = lib.versionAtLeast old.version "26.0.0";
        }
      );

      recommonmark = prev.recommonmark.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.commonmark ];
        }
      );

      rich = prev.rich.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.commonmark ];
        }
      );

      rockset = prev.rockset.overridePythonAttrs (
        _old: {
          postPatch = ''
            cp ./setup_rockset.py ./setup.py
          '';
        }
      );

      scaleapi = prev.scaleapi.overridePythonAttrs (
        _old: {
          postPatch = ''
            substituteInPlace setup.py --replace-warn "install_requires = ['requests>=2.4.2', 'enum34']" "install_requires = ['requests>=2.4.2']" || true
          '';
        }
      );

      panel = prev.panel.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.nodejs ];
        }
      );

      # Pybind11 is an undeclared dependency of scipy that we need to pick from nixpkgs
      # Make it not fail with infinite recursion
      pybind11 = prev.pybind11.overridePythonAttrs (
        old: {
          cmakeFlags = (old.cmakeFlags or [ ]) ++ [
            "-DPYBIND11_TEST=off"
          ];
          doCheck = false; # Circular test dependency

          # Link include and share so it can be used by packages that use pybind11 through cmake
          postInstall = ''
            ln -s $out/${final.python.sitePackages}/pybind11/{include,share} $out/
          '';
        }
      );

      rapidfuzz = prev.rapidfuzz.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          dontUseCmakeConfigure = true;
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'scikit-build~=0.17.0' 'scikit-build' \
              --replace-warn 'Cython==3.0.0b2' 'Cython'
          '';
        }
      );

      rasterio = prev.rasterio.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ gdal ];
      });

      referencing = prev.referencing.overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = old.postPatch or "" + ''
          sed -i "/Topic :: File Formats :: JSON/d" pyproject.toml
        '';
      });

      reportlab = prev.reportlab.overridePythonAttrs (old: {
        # They loop through LFS standard paths instead of just using pkg-config.
        postPatch = ''
          sed -i 's|"/usr/include/freetype2"|"${pkgs.lib.getDev pkgs.freetype}"|' setup.py
        '';
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.freetype ];
      });

      rfc3986-validator = prev.rfc3986-validator.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
          final.pytest-runner
        ];
      });

      rlp = prev.rlp.overridePythonAttrs {
        preConfigure = ''
          substituteInPlace setup.py --replace-warn \'setuptools-markdown\' ""
        '';
      };

      rmfuse = prev.rmfuse.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.setuptools ];
      });

      rpds-py =
        let
          getCargoHash = version: {
            "0.8.8" = "sha256-jg9oos4wqewIHe31c3DixIp6fssk742kqt4taWyOq4U=";
            "0.8.10" = "sha256-D4pbEipVn1r5rrX+wDXi97nDZJyBlkdqhmbJSgQGTLU=";
            "0.8.11" = "sha256-QZNm/b9s/qr3GHwe9wG7U9/AaQwSPHsQ0F2SFQdgPNo=";
            "0.8.12" = "sha256-wywBytnfLBnBH2yYi2eLQjASDmFN9VqPABwMuSUxN0Q=";
            "0.9.2" = "sha256-2LiQ+beFj9+kykObPNtqcg+F+8wBDzvWcauwDLHa7Yo=";
            "0.10.0" = "sha256-FXjk1Y/Eol4d1xvwz0S42OycZV0cSHM36H+zjEmNPCQ=";
            "0.10.2" = "sha256-X0Busta5y1ToLcF6/5ZiatP8m/nxFsVGW/ba0MS4hhg=";
            "0.10.3" = "sha256-iWy6BHVsKsZB0SVrh3CVhryaavk4gAQVvRdu9xBiDRg=";
            "0.10.4" = "sha256-JOzc6rB65oNhQqjuDNeSgRhvXg2fQDf5ogoYznaBj5Y=";
            "0.10.5" = "sha256-WB1PaJod7Romvme+lcTR6lh9CAbg+67ptBj838b3KFc=";
            "0.10.6" = "sha256-8bXCTrZErdE7JhuoudU/4dDndCMwvjy2a+2IY0DWDzg=";
            "0.11.0" = "sha256-4q/m+8UKAH7q7Jr95vvpU/me0pzvYTivcFA+unfOeQ8=";
            "0.12.0" = "sha256-jdr0xN3Pd/bCoKfLLFNGXHJ+G1ORAft6/W7VS3PbdHs=";
            "0.13.0" = "sha256-bHfxiBSN7/SbZiyYRj01phwrpyH7Fa3xVaA3ceWZYCE=";
            "0.13.1" = "sha256-Q6TNWCJYlHnka4N+Q2OcqSe1h066X9CZK9pUFxxUgrI=";
            "0.13.2" = "sha256-jaLSrl0oT3Fo/F0FfLvA2wDJk/Fc3d7mBqwRqyWAOsg=";
            "0.14.0" = "sha256-CXEmCxntkBI06JMBE4D5FD9GoWqq99d1xHBG/KOURL4=";
            "0.14.1" = "sha256-5CKH+bbU0DGIw6v1/AsnGxsD7TidJ55lQHQuVSgbYTo=";
            "0.14.2" = "sha256-bWFUuoi/IgIrC/g9TwDAiMvpPKe6+r/xdLf2GZIhMyE=";
            "0.15.0" = "sha256-jFpRXcLBZJ2ZFiV3TDN4qrAi2IcJEKcPnOlU6txXqoU=";
            "0.15.1" = "sha256-OAkKmSHhKwLkx77I7lSmJyjchIt1kAgGISfIWiqPkM8=";
            "0.15.2" = "sha256-4hkJ39jN2V74/eJ/MQmLAx8s0DnQTfsdN1bU4Fvfiq4=";
            "0.16.0" = "sha256-I1F9BS+0pQ7kufcK5dxfHj0LrVR8r8xM6k8mtf7emZ4=";
            "0.16.1" = "sha256-aSXLPkRGrvyp5mLDnG2D8ZPgG9a3fX+g1KVisNtRadc=";
            "0.16.2" = "sha256-aPmi/5UAkePf4nC2zRjXY+vZsAsiRZqTHyZZmzFHcqE=";
            "0.17.1" = "sha256-sFutrKLa2ISxtUN7hmw2P02nl4SM6Hn4yj1kkXrNWmI=";
            "0.18.0" = "sha256-wd1teRDhjQWlKjFIahURj0iwcfkpyUvqIWXXscW7eek=";
            "0.18.1" = "sha256-caNEmU3K5COYa/UImE4BZYaFTc3Csi3WmnBSbFN3Yn8=";
            "0.19.0" = "sha256-H9IAg4lh7cmGaML5PuyYoe026pBNhOyvb/cf+oZcv0c=";
            "0.19.1" = "sha256-qIXdoCEVGCGUnTicZp4bUTJyGpFy9dwWY03lXUbxiHg=";
            "0.20.0" = "sha256-5vbR2EbrAPJ8pb78tj/+r9nOWgQDT5aO/LUQI4kAGjU=";
            "0.20.1" = "sha256-vqJCGlp5S2wECfgleCexCb9xegA8b6wo7YNBbcsbXqk=";
            "0.21.0" = "sha256-VOmMNEdKHrPKJzs+D735Y52y47MubPwLlfkvB7Glh14=";
            "0.22.3" = "sha256-m01OB4CqDowlTAiDQx6tJ7SeP3t+EtS9UZ7Jad6Ccvc=";
          }.${version} or (
            lib.warn "Unknown rpds-py version: '${version}'. Please update getCargoHash." lib.fakeHash
          );
        in
        prev.rpds-py.overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
            inherit (old) src;
            name = "${old.pname}-${old.version}";
            hash = getCargoHash old.version;
          };
          buildInputs = old.buildInputs or [ ] ++ lib.optionals stdenv.isDarwin [
            pkgs.libiconv
          ];
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            pkgs.rustPlatform.cargoSetupHook
            pkgs.rustPlatform.maturinBuildHook
          ];
        });

      rtree = prev.rtree.overridePythonAttrs (old: {
        propagatedNativeBuildInputs = old.propagatedNativeBuildInputs or [ ] ++ [ pkgs.libspatialindex ];
        postPatch = ''
          substituteInPlace rtree/finder.py --replace-warn \
            "find_library('spatialindex_c')" \
            "'${pkgs.libspatialindex}/lib/libspatialindex_c${sharedLibExt}'"
        '';
      });

      ruamel-yaml = prev.ruamel-yaml.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ]
            ++ [ final.ruamel-yaml-clib ];
        }
      );

      ruff =
        let
          # generated with
          # curl https://api.github.com/repos/astral-sh/ruff/releases | \
          #   jq -r '.[].tag_name' | tr '\n' '\0' | xargs -0 sh -c '
          #     for version in "$@"; do
          #       nix_prefetch=$(nix-prefetch-github astral-sh ruff --rev "$version") || exit;
          #       echo "\"${version#v}\" = \"$(echo "$nix_prefetch" | jq -r ".sha256 // .hash")\";"
          #     done' _
          getRepoHash = version: {
            "0.8.6" = "sha256-9YvHmNiKdf5hKqy9tToFSQZM2DNLoIiChcfjQay8wbU=";
            "0.7.4" = "sha256-viDjUfj/OWYU7Fa7mqD2gYoirKFSaTXPPi0iS7ibiiU=";
            "0.7.3" = "sha256-TQ7nBd2S77VYShYxpxZ3CfCMiOGyl9EtIv9nXZjmijc=";
            "0.7.2" = "sha256-9zbLlQfDeqdUp1AKP/NRMZl9KeTyyTJz7JZVW/GGRM0=";
            "0.7.1" = "sha256-TPr6YdSb5JKltXHDi1PdGzPYjmmsbCFQKxIiJURrBMI=";
            "0.7.0" = "sha256-//ayB5ayYM5FqiSXDDns2tIL+PJ0Osvkp8+MEEL0L+8=";
            "0.6.9" = "sha256-O8iRCVxHrchBSf9kLdkdT0+oMi+5fLCAF9CMEsPrHqw=";
            "0.6.8" = "sha256-guRg35waq6w+P8eaXJFwMtROoXU3d3yURGwzG2SIzhc=";
            "0.6.7" = "sha256-1udxvl98RveGJmnG8kwlecWD9V+BPadA/YE8jbt9jNo=";
            "0.6.6" = "sha256-8EKOBlF6bgjgB5t3KP4AcWU7YkLaiFoAj+wuJWEOAic=";
            "0.6.5" = "sha256-1V95S0FWHzCxztgip+rbCjji4O71D+QdcSZ/hbABeKg=";
            "0.6.4" = "sha256-AldYWbLtkVtM1sWBCgNym9RZ0QszIh59vQhoysl5/3I=";
            "0.6.3" = "sha256-5jS2NCl01kgUAd8hFtjJCOwRxi0XMM2x7VMpJLEgbOQ=";
            "0.6.2" = "sha256-pdaOTMzEOfAKFK+P/4f51bQbmCssMNvq2OGvGVPzvhw=";
            "0.6.1" = "sha256-/tD1TJRq+/2/KMmRHqB8ZbShoDkXG9nnBqacxXYKjbg=";
            "0.6.0" = "sha256-s4JIqeOIxJ3NQ61fuBYYF0kSovEMcVHRExLB7kpICeg=";
            "0.5.7" = "sha256-swnh2bfmwPP1BHlnKbOtRdskMMArZgP/ErtrnXKRiC8=";
            "0.5.6" = "sha256-70EEdr6gjdE8kjgMXYzHpqCzt4E73/Gr7ksNEbLlBoA=";
            "0.5.5" = "sha256-dqfK6YdAV4cdUYB8bPE9I5FduBJ90RxUA7TMvcVq6Zw=";
            "0.5.4" = "sha256-dvvhd84T2YaNR5yu1uYcqwHjVzcWXvlXthyMBf8qZzE=";
            "0.5.3" = "sha256-+tlE5izXD+kNVwF0nucRsLALYQnkAnCZEONPVDG6dwk=";
            "0.5.2" = "sha256-g71RqbEoCpmCjd0CKkc++yv00ohoORDeMYAwYEHKhW4=";
            "0.5.1" = "sha256-2tW/p9A7jpQg8ZmSF7KRuN6kBNKK1cfjnS9KlvnCpQA=";
            "0.5.0" = "sha256-OjMoa247om4DLPZ6u0XPMd5L+LYlVzHL39plCCr/fYE=";
            "0.4.10" = "sha256-FRBuvXtnbxRWoI0f8SM0U0Z5TRyX5Tbgq3d34Oh2bG4=";
            "0.4.9" = "sha256-40ZXD52d/kZNkSZ64H/s/OiiU99IiblGfYa4KmU8xD4=";
            "0.4.8" = "sha256-XuAJ65R80+IntWBGikG1cxAH8Tr3mnwQvSxeKFQj2ac=";
            "0.4.7" = "sha256-1WQQpIdGFWEq6HzFFA5qRC3wnqtUvdzC/6VIkDY1pZI=";
            "0.4.6" = "sha256-ECFBciJjVmz8yvZci6dV4L3o4objkbU5HwB2qy0Mqv4=";
            "0.4.5" = "sha256-+8JKzKKWPQEanU2mh8p5sRjnoU6DawTQQi43qRXVXIg=";
            "0.4.4" = "sha256-ViXKGcuDla428mI2Am67gtOxfia5VfR+ry2qyczXO/I=";
            "0.4.3" = "sha256-kduKKaCeqwSnCOPPNlNI6413OAvYkEGM2o4wOMqLZmc=";
            "0.4.2" = "sha256-AnAJi0srzwxU/22Uy+OjaSBdAEjCXH99J7VDvI03HDU=";
            "0.4.1" = "sha256-VTFwuNoqh0RLk0AHTPWEwrja0/aErmUlz82MnCc58jA=";
            "0.4.0" = "sha256-9XF7aH3cK8t/UqP5V6EnBiZAngN8ELyMAYke8oxwyLo=";
            "0.3.7" = "sha256-PS4YJpVut+KtEgSlTVtoVdlu6FVipPIzsl01/Io5N64=";
            "0.3.6" = "sha256-Xgpeyp5OAuBQgYYVIaGteY0NAePEYJTZDUxMh0a3+/g=";
            "0.3.5" = "sha256-sGmNrkZv03yzEm9fM00H/BZnVr915LW3qGWjci1QACc=";
            "0.3.4" = "sha256-P0k/0tWbhY2HaxI4QThxpHD48JUjtF/d3iU4MIFhdHI=";
            "0.3.3" = "sha256-uErhX0GyJ1P5YFpQkwwi7oKvLkK7lziAzz/3at7pfA0=";
            "0.3.2" = "sha256-2Pt2HuDB9JLD9E1q0JH7jyVoc0II5uVL1l8pAod+9V4=";
            "0.3.1" = "sha256-MuvVpMBEQSOz6vSEhw7fmvAwgUu/7hrbtP8/MsIL57c=";
            "0.3.0" = "sha256-U77Bwgbt2T8xkamrWOnOpNRF+8skLWhX8JqgPqowcQw=";
            "0.2.2" = "sha256-wCjPlKlw0IAh5oH4W7DUw3KBxR4bt9Ho7ncRL5TbD/0=";
            "0.2.1" = "sha256-VcDDGi6fPGZ75+J7aOSr7S6Gt5bpr0vM2Sk/Utlmf4k=";
            "0.2.0" = "sha256-xivZHfQcdlp2ccpZiKb+Z70Ej8Vquqy/5A+MLpkEf2E=";
            "0.1.15" = "sha256-DzdzMO9PEwf4HmpG8SxRJTmdrmkXuQ8RsIchvsKstH8=";
            "0.1.14" = "sha256-UTXC0wbiH/Puu8gOXsD/yLMpre3IJPaT73Z/0rGStYU=";
            "0.1.13" = "sha256-cH/Vw04QQ3U7E1ZCwozjhPcn0KVljP976/p3okrBpEU=";
            "0.1.12" = "sha256-Phmg/WpuiUhAMZwut/i6biynYXTTaIOxRTIyJ8NNvCs=";
            "0.1.11" = "sha256-yKb74GADeALai4qZ/+dR6u/QzKQF5404+YJKSYU/oFU=";
            "0.1.10" = "sha256-uFbqL4hFVpH12gSCUmib+Q24cApWKtGa8mRmKFUTQok=";
            "0.1.9" = "sha256-Dtzzh4ersTLbAsG06d8dJa1rFgsruicU0bXl5IAUZMg=";
            "0.1.8" = "sha256-zf2280aSmGstcgxoU/IWtdtdWExvdKLBNh4Cn5tC1vU=";
            "0.1.7" = "sha256-Al256/8A/efLrf97xCwEocwgs3ngPnEAmkfcLWdlkTw=";
            "0.1.6" = "sha256-EX1tXe8KlwjrohzgzKDeJP0PjfKw8+lnQ7eg9PAUAfQ=";
            "0.1.5" = "sha256-g52cIw0af/wQSuA4QhC2dCjcDGikirswBDAtwf8Drvo=";
            "0.1.4" = "sha256-vdhyzFUimc9gBsLpk7WKwQQ0YtGJg3us+6JCFnXSMrI=";
            "0.1.3" = "sha256-AHnEvDzuQd6W+n9wXhMt6TJwoH1rZEY5UXbhFGwl8+g=";
            "0.1.2" = "sha256-hmjsr7Z5k0tX1e6IBYWufnQ4l7qebyqkRTuULmoHqvM=";
            "0.1.1" = "sha256-sBWB8s9QKedactLfSDPq5tCdlELkTGB0jDQH1S8Hq4k=";
            "0.1.0" = "sha256-w4xFIYmvK8nCeCIM3SxS2OdAK3LmV35h0QkXh+tYP7w=";
            "0.0.292" = "4D7p5ZMdyemDBaWcCO62bhuPPcIypegqP0YZeX+GJRQ=";
            "0.0.291" = "fAukXL0inAPdDpf//4yHYIQIKj3IifX9ObAM7VskDFI=";
            "0.0.290" = "w2RqT0n++ggeNoEcrZSAF0056ctDBKGkV+GAscQcwOc=";
            "0.0.289" = "DBYE3UkA30bFqoTCgE7SBs25wJ6bPvY63e31LEPBK7c=";
            "0.0.288" = "rDzxGIDUIxK5n8uT0vSFGrp4wOm49KtY7xKRoLZhEF8=";
            "0.0.287" = "T7PuhQnb7Ae9mYdaxDBltJWx5ODTscvEP3LcSEcSuLo=";
            "0.0.286" = "5bMfOju1uJV4+a4UTzaanpzU6PjCSK9HHMdhvKVaNcg=";
            "0.0.285" = "n5FjzngdVSHHnBpVGFXzPlUAEMx96JqjYqgKwymTMzA=";
            "0.0.284" = "MAlIepodGQL2tHRIPXsHLg4rDYgjfq1opaXIkjNNW1I=";
            "0.0.283" = "WqvTn/NGyZq9cJ417KPOVEEshDITxs6XdhwZbCXPk2o=";
            "0.0.282" = "CQsgRTpZTBj07/9SYkrQXtb5FOguCtf5LCli65v20YA=";
            "0.0.281" = "rIN2GaNrHO6s+6fMUN1a4H58ryoTr8EMjkX34YCCKaU=";
            "0.0.280" = "Pp/yurRPUHqrCD3V93z5EGMYf4IyLFQOL9d2sNe3TKs=";
            "0.0.279" = "7f/caaCbYt+Uatd12gATSJgs5Nx/X7YZhXEESl5OtWE=";
            "0.0.278" = "CM5oV9q9XYhaUV173VoFZl6dDALan4Lkl5PrvZN81c4=";
            "0.0.277" = "oFSMsiy9airi/SwOxA3YO02polvFl8ZZUHkD71c5unA=";
            "0.0.276" = "abFvjBmaY6SvfEHm/8P92s3Ns3jswLHrW2RdZc6IS64=";
            "0.0.275" = "HsoycugHzgudY3Aixv5INlOLTjLMzP+gKMMKIreiODs=";
            "0.0.274" = "0JaeLvc6pwvt9a7wAbah6sVgmHf6GParwdkiW3jQPaQ=";
            "0.0.273" = "FZWCA4oEUe7hOodtVypvqXv4REXCAEgY0s6wQSKDWuI=";
            "0.0.272" = "B4wZTKC1Z6OxXQHrG9Q9VjY6ZnA3FOoMMNfroe+1A7I=";
            "0.0.271" = "PYzWLEuhU2D6Sq1JEoyAkl4nfaMHaS7G6SLNKaoAJpE=";
            "0.0.270" = "rruNNP/VkvMQexQ+V/ASxl5flHt00YomMAVzW+eWp20=";
          }.${version} or (
            lib.warn "Unknown ruff version: '${version}'. Please update getRepoHash." lib.fakeHash
          );

          getCargoHash = version: {
            "0.8.6" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.8.6/Cargo.lock
              lockFile = ./ruff/0.8.6-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                # lock file has a revision override
                "salsa-0.18.0" = "sha256-esWNyc3TcIhFul4VjtZH991aZp03BUVgvzCFqt6GtUg=";
              };
            };
            "0.7.4" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.7.4/Cargo.lock
              lockFile = ./ruff/0.7.4-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                # lock file has a revision override
                "salsa-0.18.0" = "sha256-zUF2ZBorJzgo8O8ZEnFaitAvWXqNwtHSqx4JE8nByIg=";
              };
            };
            "0.7.3" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.7.3/Cargo.lock
              lockFile = ./ruff/0.7.3-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                # lock file has a revision override
                "salsa-0.18.0" = "sha256-zUF2ZBorJzgo8O8ZEnFaitAvWXqNwtHSqx4JE8nByIg=";
              };
            };
            "0.7.2" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.7.2/Cargo.lock
              lockFile = ./ruff/0.7.2-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                # lock file has a revision override
                "salsa-0.18.0" = "sha256-zUF2ZBorJzgo8O8ZEnFaitAvWXqNwtHSqx4JE8nByIg=";
              };
            };
            "0.6.1" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.6.1/Cargo.lock
              lockFile = ./ruff/0.6.1-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-Gu7YVqEDJUSzBqTeZH1xU0b3CWsWZrEvjIg7QpUaKBw=";
              };
            };
            "0.6.0" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.6.0/Cargo.lock
              lockFile = ./ruff/0.6.0-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-Gu7YVqEDJUSzBqTeZH1xU0b3CWsWZrEvjIg7QpUaKBw=";
              };
            };
            "0.5.7" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.5.7/Cargo.lock
              lockFile = ./ruff/0.5.7-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-Gu7YVqEDJUSzBqTeZH1xU0b3CWsWZrEvjIg7QpUaKBw=";
              };
            };
            "0.5.6" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.5.6/Cargo.lock
              lockFile = ./ruff/0.5.6-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-y5PuGeQNUHLhU8YY9wPbGk71eNZ0aM0Xpvwfyf+UZwM=";
              };
            };
            "0.5.5" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.5.5/Cargo.lock
              lockFile = ./ruff/0.5.5-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-y5PuGeQNUHLhU8YY9wPbGk71eNZ0aM0Xpvwfyf+UZwM=";
              };
            };
            "0.5.4" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.5.4/Cargo.lock
              lockFile = ./ruff/0.5.4-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-y5PuGeQNUHLhU8YY9wPbGk71eNZ0aM0Xpvwfyf+UZwM=";
              };
            };
            "0.5.3" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.5.3/Cargo.lock
              lockFile = ./ruff/0.5.3-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-y5PuGeQNUHLhU8YY9wPbGk71eNZ0aM0Xpvwfyf+UZwM=";
              };
            };
            "0.5.2" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.5.2/Cargo.lock
              lockFile = ./ruff/0.5.6-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-y5PuGeQNUHLhU8YY9wPbGk71eNZ0aM0Xpvwfyf+UZwM=";
              };
            };
            "0.5.1" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.5.1/Cargo.lock
              lockFile = ./ruff/0.5.1-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-gcaAsrrJXrWOIHUnfBwwuTBG1Mb+lUEmIxSGIVLhXaM=";
              };
            };
            "0.5.0" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/0.5.0/Cargo.lock
              lockFile = ./ruff/0.5.0-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-0.18.0" = "sha256-keVEmSwV1Su1RlOTaIu253FZidk279qA+rXcCeuOggc=";
              };
            };
            "0.4.10" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/v0.4.10/Cargo.lock
              lockFile = ./ruff/0.4.10-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-2022-0.1.0" = "sha256-mt+X1hO+5ZrCAgy6N4aArnixJ9GjY/KwM0uIMUSrDsg=";
              };
            };
            "0.4.9" = {
              # https://raw.githubusercontent.com/astral-sh/ruff/v0.4.9/Cargo.lock
              lockFile = ./ruff/0.4.9-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
                "salsa-2022-0.1.0" = "sha256-mt+X1hO+5ZrCAgy6N4aArnixJ9GjY/KwM0uIMUSrDsg=";
              };
            };
            "0.4.8" = {
              # https://github.com/astral-sh/ruff/blob/v0.4.8/Cargo.lock
              lockFile = ./ruff/0.4.8-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
              };
            };
            "0.4.7" = {
              # https://github.com/astral-sh/ruff/blob/v0.4.7/Cargo.lock
              lockFile = ./ruff/0.4.7-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
              };
            };
            "0.4.6" = {
              # https://github.com/astral-sh/ruff/blob/v0.4.6/Cargo.lock
              lockFile = ./ruff/0.4.6-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
              };
            };
            "0.4.5" = {
              # https://github.com/astral-sh/ruff/blob/v0.4.5/Cargo.lock
              lockFile = ./ruff/0.4.5-Cargo.lock;
              outputHashes = {
                "lsp-types-0.95.1" = "sha256-8Oh299exWXVi6A39pALOISNfp8XBya8z+KT/Z7suRxQ=";
              };
            };
            "0.4.4" = "sha256-K0iSCJNQ71/VfDL4LfqNHTqTfaVT/43zXhR5Kg80KvU=";
            "0.4.3" = "sha256-/ZjZjcYWdJH9NuKKohNxSYLG3Vdq2RylnCMHHr+5MtY=";
            "0.4.2" = "sha256-KpB5xHPuk5qb2yDHfe9U95qNMgW0PHX9RJcOOkKREsY=";
            "0.4.1" = "sha256-H2ULx1UXkRmCyC7fky394Q8z3HZaNbwF7IqAidY6/Ac=";
            "0.4.0" = "sha256-FRDnTv+3pn/eV/TJ+fdHiWIttcKZ8VDgF3ELjxqZp14=";
            "0.3.7" = "sha256-T5lYoWV9HdwN22ADi6ce66LM8XEOuqHx/ocTPhnl1Hk=";
            "0.3.6" = "sha256-OcZRrARGVcPUatDzmWVLHjpTaJbLd0XjAyNXMzNBxP8=";
            "0.3.5" = "sha256-ckKG2kNxUt/mJq4DBk+E2aee6xx+/S50z2Cxfqni6io=";
            "0.3.4" = "sha256-trCl2IBPh33vZ14PGLxxItb1S0/6UXnF1GMFNwvlnZA=";
            "0.3.3" = "sha256-OY7KkI6DjiGlc/bV1/1Lx4AdxuGnJxL+LLj1gnV7Ibs=";
            "0.3.2" = "sha256-3Z1rr70goiYpHn6knO2KgjXwOMwD3EhY3PwsdGqKNhM=";
            "0.3.1" = "sha256-DPynb9T4M5Hf3YfTARybJsvpvgQuuLZ+dGSG6v5YJYE=";
            "0.3.0" = "sha256-tyMw1Io8FpyOWWwkQu8HK1nEmOns/aKm2GtLI8B7NBc=";
            "0.2.2" = "sha256-LgKiUWd7mWVuZDsnM+1KVS5Trze4Funh2w8cILzsRY8=";
            "0.2.1" = "sha256-atuZw8TML/CujTsXGLdSoahP1y04qdxjcmiNVLy0fns=";
            "0.2.0" = "sha256-zlatDyCWZr4iFY0fVCzhQmUGJxKMQvZd6HAt0PFlMwY=";
            "0.1.15" = "sha256-M6qGG/JniEdNO2Qcw7u52JUJahucgiZcjWOaq50E6Ns=";
          }.${version} or (
            lib.warn "Unknown ruff version: '${version}'. Please update getCargoHash." null
          );

          sha256 = getRepoHash prev.ruff.version;
        in
        prev.ruff.overridePythonAttrs (old:
          let
            src = pkgs.fetchFromGitHub {
              owner = "astral-sh";
              repo = "ruff";
              rev = if (lib.versionOlder old.version "0.5.0") then "v${old.version}" else old.version;
              inherit sha256;
            };

            cargoDeps = let hash = getCargoHash prev.ruff.version; in
              if (hash == null || builtins.isAttrs hash) then
                pkgs.rustPlatform.importCargoLock
                  (
                    {
                      lockFile = "${src.out}/Cargo.lock";
                    } // (if hash == null then { } else hash)
                  ) else
                pkgs.rustPlatform.fetchCargoTarball {
                  name = "ruff-${old.version}-cargo-deps";
                  inherit src hash;
                };
          in
          lib.optionalAttrs (!(old.src.isWheel or false)) {
            inherit src cargoDeps;

            buildInputs = old.buildInputs or [ ] ++ lib.optionals stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.Security
              pkgs.darwin.apple_sdk.frameworks.CoreServices
              pkgs.libiconv
            ];
            nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
              pkgs.rustPlatform.cargoSetupHook
              pkgs.rustPlatform.maturinBuildHook
            ];
          });

      scipy = prev.scipy.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++
            [ gfortran ] ++
            lib.optionals (lib.versionAtLeast prev.scipy.version "1.7.0") [ final.pythran ] ++
            lib.optionals (lib.versionAtLeast prev.scipy.version "1.9.0") [ final.meson-python pkg-config ];
          dontUseMesonConfigure = true;
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.pybind11 ];
          setupPyBuildFlags = [ "--fcompiler='gnu95'" ];
          enableParallelBuilding = true;
          buildInputs = old.buildInputs or [ ] ++ [ final.numpy.blas ];
          prePatch = (old.prePatch or "") + lib.optionalString
            (stdenv.isDarwin && (lib.versionAtLeast old.version "1.14.0"))
            ''
              substituteInPlace scipy/meson.build \
                --replace-warn "'xcrun'" "'${pkgs.buildPackages.xcbuild}/bin/xcrun'"
            '';
          preConfigure = ''
            export NPY_NUM_BUILD_JOBS=$NIX_BUILD_CORES
          '' + lib.optionalString (lib.versionOlder prev.scipy.version "1.11.1") ''
            sed -i '0,/from numpy.distutils.core/s//import setuptools;from numpy.distutils.core/' setup.py
          '';
          preBuild = lib.optionalString (lib.versionOlder prev.scipy.version "1.9.0") ''
            ln -s ${final.numpy.cfg} site.cfg
          '';
          postPatch = ''
            substituteInPlace pyproject.toml \
              --replace-warn 'wheel<0.38.0' 'wheel' \
              --replace-warn 'pybind11>=2.4.3,<2.11.0' 'pybind11' \
              --replace-warn 'pythran>=0.9.12,<0.13.0' 'pythran' \
              --replace-warn 'setuptools<=51.0.0' 'setuptools'
            sed -i pyproject.toml -e 's/numpy==[0-9]\+\.[0-9]\+\.[0-9]\+;/numpy;/g'
          '';
        }
      );

      scikit-build-core = prev.scikit-build-core.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            final.pyproject-metadata
            final.pathspec
            # these are _intentionally_ the *Python* wrappers for cmake and
            # ninja, both of which are used by scikit-build-core
            final.cmake
            final.ninja
          ];
        }
      );

      scikit-image = prev.scikit-image.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            final.pythran
            final.packaging
            final.wheel
            final.numpy
          ];
        }
      );

      gitlint = prev.gitlint.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          postPatch = old.postPatch or "" + ''
            {
              echo '[tool.hatch.build.targets.wheel]'
              echo 'packages = ["gitlint-core/gitlint"]'
            } >> pyproject.toml
          '';
        }
      );

      ckzg = prev.ckzg.overridePythonAttrs (old: {
        postPatch = old.postPatch or lib.optionalString stdenv.cc.isGNU ''
          substituteInPlace src/Makefile --replace-warn 'CC = clang' 'CC = gcc'
        '';
      });

      scikit-learn = prev.scikit-learn.overridePythonAttrs (
        old: lib.optionalAttrs (!(old.src.isWheel or false)) {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            gfortran
          ] ++ lib.optionals stdenv.cc.isClang [
            pkgs.llvmPackages.openmp
          ] ++ lib.optionals stdenv.isLinux [
            pkgs.glibcLocales
          ];

          enableParallelBuilding = true;

          postPatch = old.postPatch or "" + ''
            patchShebangs .
            substituteInPlace pyproject.toml --replace-warn 'setuptools<60.0' 'setuptools'
          ''
            # patchShebangs doesn't seem to like #!/usr but accepts #! /usr ¯\_(ツ)_/¯
            + lib.optionalString (lib.versionAtLeast old.version "1.5") ''
            substituteInPlace sklearn/_build_utils/version.py --replace-warn "#!/usr/bin/env python" "#!${final.python}/bin/python"
          '';
        }
      );

      secp256k1 = prev.secp256k1.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
          pkg-config
          autoconf
          automake
          libtool
        ];
        buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        doCheck = false;
        # Local setuptools versions like "x.y.post0" confuse an internal check
        postPatch = ''
          substituteInPlace setup.py \
            --replace-warn 'setuptools_version.' '"${final.setuptools.version}".' \
            --replace-warn 'pytest-runner==' 'pytest-runner>='
        '';
      });

      selenium =
        let
          v4orLater = lib.versionAtLeast prev.selenium.version "4";
          selenium = prev.selenium.override {
            # Selenium >=4 is built with Bazel
            preferWheel = v4orLater;
          };
        in
        selenium.overridePythonAttrs (old: {
          # Selenium <4 can be installed from sources, with setuptools
          buildInputs = old.buildInputs or [ ] ++ (lib.optionals (!v4orLater) [ final.setuptools ]);
        });

      shapely = prev.shapely.overridePythonAttrs (
        old: {
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.geos ];

          GEOS_LIBRARY_PATH = "${pkgs.geos}/lib/libgeos_c${sharedLibExt}";

          GEOS_LIBC = lib.optionalString (!stdenv.isDarwin) "${lib.getLib stdenv.cc.libc}/lib/libc${sharedLibExt}.6";

          # Fix library paths
          postPatch = lib.optionalString (!(old.src.isWheel or false)) (old.postPatch or "" + ''
            ${pkgs.python3.interpreter} ${./shapely-rewrite.py} shapely/geos.py
            substituteInPlace pyproject.toml --replace-warn 'setuptools<64' 'setuptools'
          '');
        }
      );

      jsii = prev.jsii.overridePythonAttrs (old: lib.optionalAttrs (!(old.src.isWheel or false)) {
        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace-warn 'setuptools~=62.2' 'setuptools' \
            --replace-warn 'wheel~=0.37' 'wheel'
        '';
      });

      shellcheck-py = prev.shellcheck-py.overridePythonAttrs (old: {
        # Make fetching/installing external binaries no-ops
        preConfigure =
          let
            fakeCommand = "type('FakeCommand', (Command,), {'initialize_options': lambda self: None, 'finalize_options': lambda self: None, 'run': lambda self: None})";
          in
          ''
            # remove setup.cfg since it causes remote package access
            rm -f setup.cfg

            substituteInPlace setup.py \
              --replace-warn "'fetch_binaries': fetch_binaries," "'fetch_binaries': ${fakeCommand}," \
              --replace-warn "'install_shellcheck': install_shellcheck," "'install_shellcheck': ${fakeCommand},"
          '';

        propagatedUserEnvPkgs = old.propagatedUserEnvPkgs or [ ] ++ [
          pkgs.shellcheck
        ];
      });

      soundfile =
        let
          patch = ''
            substituteInPlace soundfile.py \
              --replace-warn "_find_library('sndfile')" "'${pkgs.libsndfile.out}/lib/libsndfile${sharedLibExt}'"
          '';
        in
        prev.soundfile.overridePythonAttrs (old: {
          postInstall = pkgs.lib.optionalString (old.src.isWheel or false) ''
            pushd "$out/${final.python.sitePackages}"
            ${patch}
            popd
          '';
          postPatch = pkgs.lib.optionalString (!(old.src.isWheel or false)) ''
            ${patch}
          '';
        });

      sqlmodel = prev.sqlmodel.overridePythonAttrs (old: {
        # sqlmodel's pyproject.toml lists version = "0" that it changes during a build phase
        # If this isn't fixed, it gets a vague "ERROR: No matching distribution for sqlmodel..." error
        patchPhase = builtins.concatStringsSep "\n" [
          (old.patchPhase or "")
          ''
            substituteInPlace "pyproject.toml" --replace-warn 'version = "0"' 'version = "${old.version}"'
          ''
        ];
      });

      suds = prev.suds.overridePythonAttrs (_old: {
        # Fix naming convention shenanigans.
        # https://github.com/suds-community/suds/blob/a616d96b070ca119a532ff395d4a2a2ba42b257c/setup.py#L648
        SUDS_PACKAGE = "suds";
      });

      systemd-python = prev.systemd-python.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.systemd ];
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
      });

      tables = prev.tables.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pywavelets ];
          HDF5_DIR = lib.getDev pkgs.hdf5;
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.hdf5 final.numpy final.numexpr ];
        }
      );

      tempora = prev.tempora.overridePythonAttrs (
        old: {
          # required for the extra "toml" dependency in setuptools_scm[toml]
          buildInputs = old.buildInputs or [ ] ++ [
            final.toml
          ];
        }
      );

      tensorboard = prev.tensorboard.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            final.wheel
            final.absl-py
          ];
          HDF5_DIR = "${pkgs.hdf5}";
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            pkgs.hdf5
            final.google-auth-oauthlib
            final.tensorboard-plugin-wit
            final.numpy
            final.markdown
            final.tensorboard-data-server
            final.grpcio
            final.protobuf
            final.werkzeug
            final.absl-py
          ];
        }
      );

      tensorflow-io-gcs-filesystem = prev.tensorflow-io-gcs-filesystem.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            pkgs.libtensorflow
          ];
        }
      );

      tensorflow = prev.tensorflow.overridePythonAttrs (
        _old: tensorflowAttrs
      );

      tensorflow-macos = prev.tensorflow-macos.overridePythonAttrs (
        # Alternative tensorflow community package for MacOS only.
        #
        # We don't want to create an implicit dependency on the normal
        # tensorflow package, because some versions don't exist for MacOS,
        # especially ARM Macs.
        _old: tensorflowAttrs
      );

      tensorpack = prev.tensorpack.overridePythonAttrs (
        _old: {
          postPatch = ''
            substituteInPlace setup.cfg --replace-warn "# will call find_packages()" ""
          '';
        }
      );

      thrift = prev.thrift.overridePythonAttrs (old: {
        postPatch = old.postPatch or "" + lib.optionalString (final.pythonAtLeast "3.12") ''
          substituteInPlace setup.cfg --replace-warn 'optimize = 1' 'optimize = 0'
        '';
      });

      tinycss2 = prev.tinycss2.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      torch = prev.torch.overridePythonAttrs (old: {
        # torch has an auto-magical way to locate the cuda libraries from site-packages.
        autoPatchelfIgnoreMissingDeps = true;

        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
          final.numpy
          final.packaging
        ];
      });

      torchaudio = prev.torchaudio.overridePythonAttrs (old: {
        autoPatchelfIgnoreMissingDeps = true;

        # (no patchelf on darwin, since no elves there.)
        preFixup = lib.optionals (!stdenv.isDarwin) ''
          addAutoPatchelfSearchPath "${final.torch}/${final.python.sitePackages}/torch/lib"
        '';

        buildInputs = old.buildInputs or [ ] ++ [
          final.torch
        ];
      });

      torchvision = prev.torchvision.overridePythonAttrs (old: {
        autoPatchelfIgnoreMissingDeps = true;

        # (no patchelf on darwin, since no elves there.)
        preFixup = lib.optionals (!stdenv.isDarwin) ''
          addAutoPatchelfSearchPath "${final.torch}/${final.python.sitePackages}/torch/lib"
        '';

        buildInputs = old.buildInputs or [ ] ++ [
          final.torch
        ];
      });

      # Circular dependency between triton and torch (see https://github.com/openai/triton/issues/1374)
      # You can remove this once triton publishes a new stable build and torch takes it.
      triton = prev.triton.overridePythonAttrs (old: {
        propagatedBuildInputs = (removePackagesByName (old.propagatedBuildInputs or [ ]) [ final.torch ]) ++ [
          # Used in https://github.com/openai/triton/blob/3f8d91bb17f6e7bc33dc995ae0860db89d351c7b/python/triton/common/build.py#L10
          final.setuptools
        ];
        pipInstallFlags = [ "--no-deps" ];
      });

      typed_ast = prev.typed-ast.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
          final.pytest-runner
        ];
      });

      urwidtrees = prev.urwidtrees.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            final.urwid
          ];
        }
      );

      vose-alias-method = prev.vose-alias-method.overridePythonAttrs (
        _old: {
          postInstall = ''
            rm -f $out/LICENSE
          '';
        }
      );

      vispy = prev.vispy.overrideAttrs (
        _: {
          inherit (pkgs.python3.pkgs.vispy) patches;
        }
      );

      uvloop = prev.uvloop.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ lib.optionals stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.ApplicationServices
            pkgs.darwin.apple_sdk.frameworks.CoreServices
          ];
        }
      );

      watchfiles =
        let
          # Watchfiles does not include Cargo.lock in tarball released on PyPi for versions up to 0.17.0
          getRepoHash = version: {
            "0.24.0" = "sha256-uc4CfczpNkS4NMevtRxhUOj9zTt59cxoC0BXnuHFzys=";
            "0.23.0" = "sha256-kFScg3pkOD0gASRtfXSfwZxyW/XvW9x0zgMn0AQek4A=";
            "0.22.0" = "sha256-TtRSRgtMOqsnhdvsic3lg33xlA+r/DcYHlzewSOu/44=";
            "0.21.0" = "sha256-/qNgkPF5N8jzSV3M0YFWvQngZ4Hf4WM/GBS1LtgFbWM=";
            "0.20.0" = "sha256-eoKF6uBHgML63DrDlC1zPfDu/mAMoaevttwqHLCKh+M=";
            "0.19.0" = "sha256-NmmeoaIfFMNKCcjH6tPnkpflkN35bKlT76MqF9W8LBc=";
            "0.18.1" = "sha256-XEhu6M1hFi3/gAKZcei7KJSrIhhlZhlvZvbfyA6VLR4=";
            "0.18.0" = "sha256-biGGn0YAUbSO1hCJ4kU0ZWlqlXl/HRrBS3iIA3myRI8=";
            "0.17.0" = "1swpf265h9qq30cx55iy6jjirba3wml16wzb68k527ynrxr7hvqx";
            "0.16.1" = "1ss6gzcr6js2d2sddgz1p52gyiwpqmgrxm8r6wim7gnm4wvhav8a";
            "0.15.0" = "14k3avrj7v794kk4mk2xggn40a4s0zg8iq8wmyyyrf7va6hz29hf";
            "0.14.1" = "1pgfbhxrvr3dw46x9piqj3ydxgn4lkrfp931q0cajinrpv4acfay";
            "0.14" = "0lml67ilyly0i632pffdy1gd07404vx90xnkw8q6wf6xp5afmkka";
            "0.13" = "0rkz8yr01mmxm2lcmbnr9i5c7n371mksij7v3ws0aqlrh3kgww02";
            "0.12" = "16788a0d8n1bb705f0k3dvav2fmbbl6pcikwpgarl1l3fcfff8kl";
            "0.11" = "0vx56h9wfxj7x3aq7jign4rnlfm7x9nhjwmsv8p22acbzbs10dgv";
            "0.10" = "0ypdy9sq4211djqh4ni5ap9l7whq9hw0vhsxjfl3a0a4czlldxqp";
          }.${version};
          sha256 = getRepoHash prev.watchfiles.version;

          getCargoHash = version: {
            "0.24.0".outputHashes = {
              "notify-6.1.1" = "sha256-lT3R5ZQpjx52NVMEKTTQI90EWT16YnbqphqvZmNpw/I=";
            };
            "0.23.0" = "sha256-m7XFpbujWFmDNSDydY3ec6b+AGgrfo3+TTbRN7te8bY=";
            "0.22.0" = "sha256-pl5BBOxrxvPvBJTnTqvWNFecoJwfyuAs4xZEgmg+T+w=";
            "0.21.0" = "sha256-KDm1nGeg4oDcbopedPfzalK2XO1c1ZQUZu6xhfRdQx4=";
            "0.20.0" = "sha256-ChUs7YJE1ZEIONhUUbVAW/yDYqqUR/k/k10Ce7jw8Xo=";
          }.${version} or (
            lib.warn "Unknown watchfiles version: '${version}'. Please update getCargoHash." null
          );
        in
        prev.watchfiles.overridePythonAttrs (old:
          let
            src = pkgs.fetchFromGitHub {
              owner = "samuelcolvin";
              repo = "watchfiles";
              rev = "v${old.version}";
              inherit sha256;
            };

            cargoDeps = let hash = getCargoHash prev.watchfiles.version; in
              if hash == null || lib.isAttrs hash then
                pkgs.rustPlatform.importCargoLock
                  ({
                    lockFile = "${src.out}/Cargo.lock";
                  } // (lib.optionalAttrs (lib.isAttrs hash) hash)) else
                pkgs.rustPlatform.fetchCargoTarball {
                  name = "watchfiles-${old.version}-cargo-deps";
                  inherit src hash;
                };

          in
          lib.optionalAttrs (!old.src.isWheel or false) {
            inherit src cargoDeps;

            patchPhase = builtins.concatStringsSep "\n" [
              (old.patchPhase or "")
              ''
                substituteInPlace "Cargo.lock" --replace-warn 'version = "0.0.0"' 'version = "${old.version}"'
                substituteInPlace "Cargo.toml" --replace-warn 'version = "0.0.0"' 'version = "${old.version}"'
              ''
            ];
            buildInputs = old.buildInputs or [ ] ++ lib.optionals stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.Security
              pkgs.darwin.apple_sdk.frameworks.CoreServices
              pkgs.libiconv
            ];
            nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
              pkgs.rustPlatform.cargoSetupHook
              pkgs.rustPlatform.maturinBuildHook
            ];
          });

      weasyprint = prev.weasyprint.overridePythonAttrs (
        old: {
          inherit (pkgs.python3.pkgs.weasyprint) patches;
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ final.pytest-runner ];
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      web3 = prev.web3.overridePythonAttrs {
        preConfigure = ''
          substituteInPlace setup.py --replace-warn \'setuptools-markdown\' ""
        '';
      };

      weblate-language-data = prev.weblate-language-data.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [
            final.translate-toolkit
          ];
        }
      );

      zipp = if prev.zipp == null then null else
      prev.zipp.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            final.toml
          ];
        }
      );

      psutil = prev.psutil.overridePythonAttrs (
        old: {
          # Fix for v5.9.8
          # See https://github.com/conda-forge/psutil-feedstock/pull/71/files/8a53fbac242e9cb6c7fe543fdcab554c6c12aecf#r1460167074
          NIX_CFLAGS_COMPILE = "-DkIOMainPortDefault=0";
          buildInputs = old.buildInputs or [ ]
            ++ lib.optionals (stdenv.isDarwin && stdenv.isx86_64) [ pkgs.darwin.apple_sdk.frameworks.CoreFoundation ]
            ++ lib.optionals stdenv.isDarwin [ pkgs.darwin.apple_sdk.frameworks.IOKit ];
        }
      );

      sentencepiece = prev.sentencepiece.overridePythonAttrs (
        old: {
          dontUseCmakeConfigure = true;
          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            pkg-config
            cmake
            pkgs.gperftools
          ];
          buildInputs = old.buildInputs or [ ] ++ [
            pkgs.sentencepiece
          ];
        }
      );

      sentence-transformers = prev.sentence-transformers.overridePythonAttrs (
        old: {
          buildInputs =
            old.buildInputs or [ ]
            ++ [ final.typing-extensions ];
        }
      );

      supervisor = prev.supervisor.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [
            final.meld3
            final.setuptools
          ];
        }
      );

      cytoolz = prev.cytoolz.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.toolz ];
        }
      );

      # For some reason the toml dependency of tqdm declared here:
      # https://github.com/tqdm/tqdm/blob/67130a23646ae672836b971e1086b6ae4c77d930/pyproject.toml#L2
      # is not translated correctly to a nix dependency.
      tqdm = prev.tqdm.overridePythonAttrs (
        old: {
          buildInputs = [ prev.toml ] ++ old.buildInputs or [ ];
        }
      );

      watchdog = prev.watchdog.overrideAttrs (
        old: {
          buildInputs = old.buildInputs or [ ]
            ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.darwin.apple_sdk.frameworks.CoreServices ];
        }
      );

      pye3d = prev.pye3d.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ]
          ++ [ pkgs.eigen final.scikit-build ];

        postPatch = ''
          sed -i "2i version = ${old.version}" setup.cfg
        '';

        dontUseCmakeConfigure = true;
      });

      # pyee cannot find `vcversioner` and other "setup requirements", so it tries to
      # download them from the internet, which only works when nix sandboxing is disabled.
      # Additionally, since pyee uses vcversioner to specify its version, we need to do this
      # manually specify its version.
      pyee = prev.pyee.overrideAttrs (
        old: {
          postPatch = old.postPatch or "" +
            (lib.optionalString (lib.versionOlder old.version "10.0.0")
              ''
                sed -i setup.py \
                  -e '/setup_requires/,/],/d' \
                  -e 's/vcversioner={},/version="${old.version}",/'
              '');
        }
      );

      # nixpkgs has setuptools_scm 4.1.2
      # but newrelic has a seemingly unnecessary version constraint for <4
      # So we patch that out
      newrelic = prev.newrelic.overridePythonAttrs (
        old: {
          postPatch = old.postPatch or "" + ''
            substituteInPlace setup.py --replace-warn '"setuptools_scm>=3.2,<4"' '"setuptools_scm"'
          '';
        }
      );

      wxpython = prev.wxpython.overridePythonAttrs (old:
        let
          localPython = final.python.withPackages (ps: with ps; [
            setuptools
            numpy
            six
            attrdict
            sip
          ]);
        in
        {
          DOXYGEN = "${pkgs.doxygen}/bin/doxygen";

          nativeBuildInputs = with pkgs; [
            which
            doxygen
            gtk3
            pkg-config
            autoPatchelfHook
          ] ++ old.nativeBuildInputs or [ ];

          buildInputs = with pkgs; [
            gtk3
            webkitgtk
            ncurses
            SDL2
            xorg.libXinerama
            xorg.libSM
            xorg.libXxf86vm
            xorg.libXtst
            xorg.xorgproto
            gst_all_1.gstreamer
            gst_all_1.gst-plugins-base
            libGLU
            libGL
            libglvnd
            mesa
          ] ++ old.buildInputs or [ ];

          buildPhase = ''
            ${localPython.interpreter} build.py -v build_wx
            ${localPython.interpreter} build.py -v dox etg --nodoc sip
            ${localPython.interpreter} build.py -v build_py
          '';

          installPhase = ''
            ${localPython.interpreter} setup.py install --skip-build --prefix=$out
          '';
        });

      marisa-trie = prev.marisa-trie.overridePythonAttrs (
        old: {
          buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ];
        }
      );

      ua-parser = prev.ua-parser.overridePythonAttrs (
        old: {
          propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.pyyaml ];
        }
      );

      pygraphviz = prev.pygraphviz.overridePythonAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkg-config ];
        buildInputs = old.buildInputs or [ ] ++ [ pkgs.graphviz ];
      });

      pysqlite = prev.pysqlite.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ pkgs.sqlite ];
        patchPhase = ''
          substituteInPlace "setup.cfg"                                     \
                  --replace-warn "/usr/local/include" "${pkgs.sqlite.dev}/include"   \
                  --replace-warn "/usr/local/lib" "${pkgs.sqlite.out}/lib"
          ${lib.optionalString (!stdenv.isDarwin) ''export LDSHARED="$CC -pthread -shared"''}
        '';
      });

      selinux = prev.selinux.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ final.setuptools-scm ];
      });

      setuptools-scm = prev.setuptools-scm.overridePythonAttrs (_old: {
        setupHook = pkgs.writeText "setuptools-scm-setup-hook.sh" ''
          poetry2nix-setuptools-scm-hook() {
              if [ -z "''${dontPretendSetuptoolsSCMVersion-}" ]; then
                export SETUPTOOLS_SCM_PRETEND_VERSION="$version"
              fi
          }

          preBuildHooks+=(poetry2nix-setuptools-scm-hook)
        '';
      });

      uwsgi = prev.uwsgi.overridePythonAttrs
        (old:
          {
            buildInputs = old.buildInputs or [ ] ++ [ pkgs.ncurses ];
          } // lib.optionalAttrs (lib.versionAtLeast old.version "2.0.19" && lib.versionOlder old.version "2.0.20") {
            sourceRoot = ".";
          });

      wcwidth = prev.wcwidth.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++
          lib.optionals final.isPy27 [ (final.backports-functools-lru-cache or final.backports_functools_lru_cache) ]
        ;
      });

      wtforms = prev.wtforms.overridePythonAttrs (old: {
        buildInputs = old.buildInputs or [ ] ++ [ final.Babel ];
      });

      nbconvert =
        let
          patchExporters = lib.optionalString (lib.versionAtLeast final.nbconvert.version "6.5.0") ''
            substituteInPlace \
              ./nbconvert/exporters/templateexporter.py \
              --replace-warn \
              'root_dirs.extend(jupyter_path())' \
              'root_dirs.extend(jupyter_path() + [os.path.join("@out@", "share", "jupyter")])' \
              --subst-var out
          '';
        in
        prev.nbconvert.overridePythonAttrs (old: {
          postPatch = lib.optionalString (!(old.src.isWheel or false)) (
            patchExporters + lib.optionalString (lib.versionAtLeast final.nbconvert.version "7.0") ''
              substituteInPlace \
                ./hatch_build.py \
                --replace-warn \
                'if final.target_name not in ["wheel", "sdist"]:' \
                'if True:'
            ''
          );
          postInstall = lib.optionalString (old.src.isWheel or false) ''
            pushd $out/${final.python.sitePackages}
            ${patchExporters}
            popd
          '';
        });

      meson-python = prev.meson-python.overridePythonAttrs (_old: {
        dontUseMesonConfigure = true;
      });

      mkdocs = prev.mkdocs.overridePythonAttrs (old: {
        propagatedBuildInputs = old.propagatedBuildInputs or [ ] ++ [ final.babel ];
      });

      mkdocs-material = prev.mkdocs-material.overridePythonAttrs (old: {
        postPatch = old.postPatch or "" + ''
          substituteInPlace pyproject.toml --replace-warn 'filename = "requirements.txt"' ""
        '';
      });

      # patch mkdocstrings to fix jinja2 imports
      mkdocstrings =
        let
          patchJinja2Imports = final.pkgs.fetchpatch {
            name = "fix-jinja2-imports.patch";
            url = "https://github.com/mkdocstrings/mkdocstrings/commit/b37722716b1e0ed6393ec71308dfb0f85e142f3b.patch";
            hash = "sha256-DD1SjEvs5HBlSRLrqP3jhF/yoeWkF7F3VXCD1gyt5Fc=";
          };
        in
        prev.mkdocstrings.overridePythonAttrs (
          old: lib.optionalAttrs
            (lib.versionAtLeast old.version "0.17" && lib.versionOlder old.version "0.18")
            {
              patches = old.patches or [ ] ++ lib.optionals (!(old.src.isWheel or false)) [ patchJinja2Imports ];
              # strip the first two levels ("a/src/") when patching since we're in site-packages
              # just above mkdocstrings
              postInstall = lib.optionalString (old.src.isWheel or false) ''
                pushd "$out/${final.python.sitePackages}"
                patch -p2 < "${patchJinja2Imports}"
                popd
              '';
            }
        );

      flake8-mutable = prev.flake8-mutable.overridePythonAttrs
        (old: { buildInputs = old.buildInputs or [ ] ++ [ final.pytest-runner ]; });
      pydantic = prev.pydantic.overridePythonAttrs
        (old: { buildInputs = old.buildInputs or [ ] ++ [ pkgs.libxcrypt ]; });

      vllm = prev.vllm.overridePythonAttrs (old: {
        # vllm-nccl-cu12 will try to download NCCL 2.18.1 from the internet to
        # the ~/.config/vllm/nccl/cu12 directory, which is not allowed in Nix.
        #
        # See https://github.com/vllm-project/vllm/issues/4224
        propagatedBuildInputs = removePackagesByName (old.propagatedBuildInputs or [ ]) (lib.optionals (final ? vllm-nccl-cu12) [ final.vllm-nccl-cu12 ]);

        autoPatchelfIgnoreMissingDeps = true;
      } // lib.optionalAttrs (!(old.src.isWheel or false)) rec {
        CUDA_HOME = pkgs.symlinkJoin {
          name = "vllm-cuda-home";
          paths = [
            pkgs.cudaPackages.libcusparse
            pkgs.cudaPackages.libnvjitlink
            pkgs.cudaPackages.libcublas
            pkgs.cudaPackages.libcusolver
            pkgs.cudaPackages.cuda_nvcc
            pkgs.cudaPackages.cuda_cccl
            pkgs.cudaPackages.cuda_cudart
          ];
        };
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
          pkgs.which
        ];
        LD_LIBRARY_PATH = "${CUDA_HOME}/lib";
      });

      xformers = prev.xformers.overridePythonAttrs (_attrs: {
        autoPatchelfIgnoreMissingDeps = true;
      });

      y-py = prev.y-py.override {
        preferWheel = true;
      };
    }
  )
  # The following are dependencies of torch >= 2.0.0.
  # torch doesn't officially support system CUDA, unless you build it yourself.
  (self: super: lib.genAttrs
    (lib.concatMap
      (pkg: [ "nvidia-${pkg}-cu11" "nvidia-${pkg}-cu12" ])
      [
        "cublas"
        "cuda-cupti"
        "cuda-curand"
        "cuda-nvrtc"
        "cuda-runtime"
        "cudnn"
        "cufft"
        "curand"
        "cusolver"
        "cusparse"
        "nccl"
        "nvjitlink"
        "nvtx"
      ])
    (name: super.${name}.overridePythonAttrs (_: {
      # 1. Remove __init__.py because all the cuda packages include it
      # 2. Symlink the cuda libraries to the lib directory so autopatchelf can find them
      postFixup = ''
        rm -rf $out/${self.python.sitePackages}/nvidia/{__pycache__,__init__.py}
        ln -sfn $out/${self.python.sitePackages}/nvidia/*/lib/lib*.so* $out/lib
      '';
    })))
]
