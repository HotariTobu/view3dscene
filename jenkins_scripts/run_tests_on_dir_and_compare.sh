#!/bin/bash
set -eu

# Build view3dscene and tovrmlx3d,
# run various tests on models in directories given as arguments ($@),
# compare with output stored in repo.

# ----------------------------------------------------------------------------

# run tests
jenkins_scripts/run_tests_on_dir.sh run_tests_output.txt run_tests_output_verbose.txt "$@"

# remove OpenAL trash from outpt
sed --in-place=.bak \
  -e '/ALSA lib/d' \
  -e '/AL lib/d' \
  -e '/jack server is not running or cannot be started/d' \
  -e '/JackShmReadWritePtr/d' \
  -e '/Cannot connect to server/d' \
  run_tests_output.txt

# replace current dir (present in some output messages) with string "DIR",
# to make the result reproducible, regardless of the current directory.
REPOSITORY_DIR="`pwd`"
# REPOSITORY_DIR="`dirname \"$REPOSITORY_DIR\"`" # go to parent -- not anymore
sed --in-place=.bak2 -e "s|${REPOSITORY_DIR}|DIR|g" run_tests_output.txt

cat run_tests_output.txt

# compare with last correct output
diff -u run_tests_output.txt jenkins_scripts/run_tests_valid_output.txt
