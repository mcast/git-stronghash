#! /bin/sh

set -e

[ -f Makefile ] || perl Makefile.PL INSTALL_BASE=INST

# you'd think all the test code runs?  not exactly
unset AND_TEST_CODE
[ "$1" = '-t' ] && AND_TEST_CODE="-select_re ^t/ -select_re .*/00compile\.t$"

cover -test -select_re ^$PWD/blib $AND_TEST_CODE
