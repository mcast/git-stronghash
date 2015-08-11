#! /bin/sh

set -e

[ -f Makefile ] || perl Makefile.PL INSTALL_BASE=INST

cover -test
