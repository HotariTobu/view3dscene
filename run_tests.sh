#!/bin/bash
set -eu

# Run view3dscene tests on ../kambi_vrml_test_suite/ (and some other dirs).
# You can checkout kambi_vrml_test_suite from SVN, or download and unpack
# from [http://vrmlengine.sourceforge.net/kambi_vrml_test_suite.php],
# such that it's a sibling of view3dscene.
#
# This requires
# - view3dscene binary compiled (either in current dir,
#   or on the $PATH, see run_test_once.sh script setting VIEW3DSCENE variable)
# - stringoper binary compiled and available on $PATH
#   (stringoper comes from ../kambi_vrml_game_engine/base/tools/stringoper.lpr)
#
# For details what is tested, see run_test_once.sh script.
# By default tests are fully automatic, although you can uncomment some
# things to peek inside.
# In short: every suitable 3D model format is
# - Read, and written back to VRML. Then this written result is read back.
#   This somewhat makes sure that there are no problems with parsing
#   and saving VRML (and other) files.
# - Then we check rendering abilities, by making screenshots with
#   various renderer-optimization options.
#   (This test is currently commented out by default, as it takes a lot
#   of time...)
#
# Doesn't enter 'errors' subdir (for kambi_vrml_test_suite,
# it contains files that *should* fail when reading).
#
# Also doesn't try to check view3dscene_test_temporary_file.wrl,
# this may be leftover from interrupted previous test (it would cause
# errors that are not interesting), it will be removed by run_test_once.sh
# inside anyway.

test_dir()
{
  set +e
  find "$1" \
  '(' -type d -iname 'errors' -prune ')' -or \
  '(' -type f -name 'view3dscene_test_temporary_file.wrl' ')' -or \
  '(' -type f '(' -iname '*.wrl' -or \
                  -iname '*.wrz' -or \
                  -iname '*.wrl.gz' -or \
                  -iname '*.x3d' -or \
                  -iname '*.x3dz' -or \
                  -iname '*.x3d.gz' -or \
                  -iname '*.x3dv' -or \
                  -iname '*.x3dvz' -or \
                  -iname '*.x3dv.gz' -or \
                  -iname '*.3ds' -or \
                  -iname '*.dae' ')' \
              -exec ./run_test_once.sh '{}' ';' ')'
  set -e
}

test_dir ../kambi_vrml_test_suite/
test_dir ../vrml_engine_doc/
test_dir ../castle/data/
test_dir ../rift/data/

# This dir has fallback_prototypes in VRML 97 and X3D, two really important
# files that should be correct.
test_dir ../www/htdocs/

# Extreme test on all models within vrmlengine repository
# test_dir ../
