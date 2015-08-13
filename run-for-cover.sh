#! /bin/sh

set -e

[ -f Makefile ] || perl Makefile.PL INSTALL_BASE=INST

cover -test -select_re ^blib -select_re ^$PWD/
