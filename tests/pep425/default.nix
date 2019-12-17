{ writeText, stdenv, lib, pep425, pep425OSX, pep425Python37 }:

lib.debug.runTests {

  #
  # selectWheel
  #

  testLinuxSimple =
    let
      cs = [
        { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_10_x86_64.whl"; }
        { file = "grpcio-1.25.0-cp27-cp27m-manylinux2010_x86_64.whl"; }
      ];
    in
      {
        expr = (pep425.selectWheel cs);
        expected = [ { file = "grpcio-1.25.0-cp27-cp27m-manylinux2010_x86_64.whl"; } ];
      };

  testOSXSimple =
    let
      cs = [
        { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_10_x86_64.whl"; }
        { file = "grpcio-1.25.0-cp27-cp27m-manylinux2010_x86_64.whl"; }
      ];
    in
      {
        expr = (pep425OSX.selectWheel cs);
        expected = [ { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_10_x86_64.whl"; } ];
      };

  testLinuxPickPython37 =
    let
      cs = [
        { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_10_x86_64.whl"; }
        { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_9_x86_64.whl"; }
        { file = "grpcio-1.25.0-cp27-cp27m-manylinux1_i686.whl"; }
        { file = "grpcio-1.25.0-cp27-cp27m-manylinux2010_x86_64.whl"; }
        { file = "grpcio-1.25.0-cp37-cp37m-manylinux1_i686.whl"; }
        { file = "grpcio-1.25.0-cp37-cp37m-manylinux2010_x86_64.whl"; }
      ];
    in
      {
        expr = (pep425Python37.selectWheel cs);
        expected = [ { file = "grpcio-1.25.0-cp37-cp37m-manylinux2010_x86_64.whl"; } ];
      };

  testOSXPreferNewer =
    let
      cs = [
        { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_9_x86_64.whl"; }
        { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_12_x86_64.whl"; }
      ];
    in
      {
        expr = (pep425OSX.selectWheel cs);
        expected = [ { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_12_x86_64.whl"; } ];
      };

  testOSXNoMatch =
    let
      cs = [
        { file = "grpcio-1.25.0-cp27-cp27m-manylinux1_x86_64.whl"; }
        { file = "grpcio-1.25.0-cp27-cp27m-manylinux2010_x86_64.whl"; }
      ];
    in
      {
        expr = (pep425OSX.selectWheel cs);
        expected = [];
      };

  testLinuxPreferOlder =
    let
      cs = [
        { file = "grpcio-1.25.0-cp27-cp27m-manylinux1_x86_64.whl"; }
        { file = "grpcio-1.25.0-cp27-cp27m-manylinux2010_x86_64.whl"; }
      ];
    in
      {
        expr = (pep425.selectWheel cs);
        expected = [ { file = "grpcio-1.25.0-cp27-cp27m-manylinux1_x86_64.whl"; } ];
      };

  testLinuxNoMatch =
    let
      cs = [
        { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_9_x86_64.whl"; }
        { file = "grpcio-1.25.0-cp27-cp27m-macosx_10_12_x86_64.whl"; }
      ];
    in
      {
        expr = (pep425.selectWheel cs);
        expected = [];
      };

  testLinuxEmptyList = {
    expr = pep425.selectWheel [];
    expected = [];
  };

  testOSXEmptyList = {
    expr = pep425OSX.selectWheel [];
    expected = [];
  };

  testLinuxCffiWhlFiles =
    let
      cs = [
        { file = "cffi-1.13.2-cp27-cp27m-macosx_10_6_intel.whl"; }
        { file = "cffi-1.13.2-cp27-cp27m-manylinux1_i686.whl"; }
        { file = "cffi-1.13.2-cp27-cp27m-manylinux1_x86_64.whl"; }
        { file = "cffi-1.13.2-cp27-cp27m-win32.whl"; }
        { file = "cffi-1.13.2-cp27-cp27m-win_amd64.whl"; }
        { file = "cffi-1.13.2-cp27-cp27mu-manylinux1_i686.whl"; }
        { file = "cffi-1.13.2-cp27-cp27mu-manylinux1_x86_64.whl"; }
        { file = "cffi-1.13.2-cp34-cp34m-macosx_10_6_intel.whl"; }
        { file = "cffi-1.13.2-cp34-cp34m-manylinux1_i686.whl"; }
        { file = "cffi-1.13.2-cp34-cp34m-manylinux1_x86_64.whl"; }
        { file = "cffi-1.13.2-cp34-cp34m-win32.whl"; }
        { file = "cffi-1.13.2-cp34-cp34m-win_amd64.whl"; }
        { file = "cffi-1.13.2-cp35-cp35m-macosx_10_6_intel.whl"; }
        { file = "cffi-1.13.2-cp35-cp35m-manylinux1_i686.whl"; }
        { file = "cffi-1.13.2-cp35-cp35m-manylinux1_x86_64.whl"; }
        { file = "cffi-1.13.2-cp35-cp35m-win32.whl"; }
        { file = "cffi-1.13.2-cp35-cp35m-win_amd64.whl"; }
        { file = "cffi-1.13.2-cp36-cp36m-macosx_10_6_intel.whl"; }
        { file = "cffi-1.13.2-cp36-cp36m-manylinux1_i686.whl"; }
        { file = "cffi-1.13.2-cp36-cp36m-manylinux1_x86_64.whl"; }
        { file = "cffi-1.13.2-cp36-cp36m-win32.whl"; }
        { file = "cffi-1.13.2-cp36-cp36m-win_amd64.whl"; }
        { file = "cffi-1.13.2-cp37-cp37m-macosx_10_6_intel.whl"; }
        { file = "cffi-1.13.2-cp37-cp37m-manylinux1_i686.whl"; }
        { file = "cffi-1.13.2-cp37-cp37m-manylinux1_x86_64.whl"; }
        { file = "cffi-1.13.2-cp37-cp37m-win32.whl"; }
        { file = "cffi-1.13.2-cp37-cp37m-win_amd64.whl"; }
        { file = "cffi-1.13.2-cp38-cp38-macosx_10_9_x86_64.whl"; }
        { file = "cffi-1.13.2-cp38-cp38-manylinux1_i686.whl"; }
        { file = "cffi-1.13.2-cp38-cp38-manylinux1_x86_64.whl"; }
        { file = "cffi-1.13.2-cp38-cp38-win32.whl"; }
        { file = "cffi-1.13.2-cp38-cp38-win_amd64.whl"; }
        { file = "cffi-1.13.2.tar.gz"; }
      ];
    in
      {
        expr = pep425.selectWheel cs;
        expected = [ { file = "cffi-1.13.2-cp27-cp27m-manylinux1_x86_64.whl"; } ];
      };

  testMsgPack =
    let
      cs = [
        { file = "msgpack-0.6.2-cp27-cp27m-manylinux1_i686.whl"; }
        { file = "msgpack-0.6.2-cp27-cp27m-manylinux1_x86_64.whl"; }
        { file = "msgpack-0.6.2-cp27-cp27m-win32.whl"; }
        { file = "msgpack-0.6.2-cp27-cp27m-win_amd64.whl"; }
        { file = "msgpack-0.6.2-cp27-cp27mu-manylinux1_i686.whl"; }
        { file = "msgpack-0.6.2-cp27-cp27mu-manylinux1_x86_64.whl"; }
        { file = "msgpack-0.6.2-cp35-cp35m-macosx_10_6_intel.whl"; }
        { file = "msgpack-0.6.2-cp35-cp35m-manylinux1_i686.whl"; }
        { file = "msgpack-0.6.2-cp35-cp35m-manylinux1_x86_64.whl"; }
        { file = "msgpack-0.6.2-cp36-cp36m-macosx_10_6_intel.whl"; }
        { file = "msgpack-0.6.2-cp36-cp36m-manylinux1_i686.whl"; }
        { file = "msgpack-0.6.2-cp36-cp36m-manylinux1_x86_64.whl"; }
        { file = "msgpack-0.6.2-cp36-cp36m-win32.whl"; }
        { file = "msgpack-0.6.2-cp36-cp36m-win_amd64.whl"; }
        { file = "msgpack-0.6.2-cp37-cp37m-macosx_10_14_x86_64.whl"; }
        { file = "msgpack-0.6.2-cp37-cp37m-macosx_10_9_x86_64.whl"; }
        { file = "msgpack-0.6.2-cp37-cp37m-manylinux1_i686.whl"; }
        { file = "msgpack-0.6.2-cp37-cp37m-manylinux1_x86_64.whl"; }
        { file = "msgpack-0.6.2-cp37-cp37m-win32.whl"; }
        { file = "msgpack-0.6.2-cp37-cp37m-win_amd64.whl"; }
        { file = "msgpack-0.6.2.tar.gz"; }
      ];
    in
      {
        expr = pep425Python37.selectWheel cs;
        expected = [ { file = "msgpack-0.6.2-cp37-cp37m-manylinux1_x86_64.whl"; } ];
      };

  testNonManyLinuxWheels =
    let
      cs = [
        { file = "tensorboard-1.14.0-py2-none-any.whl"; }
        { file = "tensorboard-1.14.0-py3-none-any.whl"; }
      ];
    in
      {
        expr = pep425Python37.selectWheel cs;
        expected = [ { file = "tensorboard-1.14.0-py3-none-any.whl"; } ];
      };

  testPy2Py3Wheels =
    let
      cs = [
        { file = "tensorboard-1.14.0-py2.py3-none-any.whl"; }
      ];
    in
      {
        expr = pep425Python37.selectWheel cs;
        expected = [ { file = "tensorboard-1.14.0-py2.py3-none-any.whl"; } ];
      };

  #
  # toWheelAttrs
  #

  testToWheelAttrs =
    let
      name = "msgpack-0.6.2-cp27-cp27m-manylinux1_i686.whl";
    in
      {
        expr = pep425.toWheelAttrs name;
        expected = {
          pkgName = "msgpack";
          pkgVer = "0.6.2";
          pyVer = "cp27";
          abi = "cp27m";
          platform = "manylinux1_i686";
        };
      };

  testToWheelAttrsAny =
    let
      name = "tensorboard-1.14.0-py3-none-any.whl";
    in
      {
        expr = pep425.toWheelAttrs name;
        expected = {
          pkgName = "tensorboard";
          pkgVer = "1.14.0";
          pyVer = "py3";
          abi = "none";
          platform = "any";
        };
      };

  #
  # isPyVersionCompatible
  #

  tesPyVersionCompatible =
    let
      f = pep425.isPyVersionCompatible;
    in
      {
        expr = [
          (f "cp27" "cp27")
          (f "cp27" "cp37")
          (f "cp27" "py2")
          (f "cp27" "py3")
          (f "cp27" "py2.py3")
          (f "cp37" "py2.py3")
        ];

        expected = [
          true
          false
          true
          false
          true
        ];
      };

}
