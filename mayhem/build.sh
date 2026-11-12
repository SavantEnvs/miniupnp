#!/usr/bin/env bash
#
# Builds miniupnpc twice and the fuzz harnesses against it:
#   miniupnpc/build/test  the project's own validation programs, normal flags (run by mayhem/test.sh)
#   miniupnpc/build/fuzz  the library with $SANITIZER_FLAGS + $DEBUG_FLAGS + libFuzzer coverage, linked
#                         into every fuzz harness
#   miniupnpc/build/repro the same without coverage, linked into the -standalone reproducers
# Both build dirs sit under miniupnpc/build/, which upstream's miniupnpc/.gitignore already ignores.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
: "${SRC:=/mayhem}"
export CC CXX

cd "$SRC/miniupnpc"

# 1) Test programs, project's normal flags.
CFLAGS="-O2 $COVERAGE_FLAGS" LDFLAGS="$COVERAGE_FLAGS" make -j"$MAYHEM_JOBS" BUILD=build/test \
    build/test/minixmlvalid build/test/testupnpreplyparse build/test/testigddescparse \
    build/test/testportlistingparse build/test/testaddr_is_reserved

# 2) Sanitized libraries.
CFLAGS="-O1 $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link" make -j"$MAYHEM_JOBS" BUILD=build/fuzz build/fuzz/libminiupnpc.a
CFLAGS="-O1 $SANITIZER_FLAGS $DEBUG_FLAGS" make -j"$MAYHEM_JOBS" BUILD=build/repro build/repro/libminiupnpc.a

# 3) Harnesses: libFuzzer binary + standalone reproducer. Leak detection is off at build time.
mkdir -p build/fuzz/harness build/repro/harness
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.c" -o build/fuzz/harness/lsan_off.o
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o build/repro/harness/standalone_main.o
for h in testminixml fuzz_upnpreplyparse fuzz_portlistingparse fuzz_igddesc fuzz_httpresponse fuzz_parseurl; do
  $CC -O1 $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link -I include -I src -I build/fuzz \
      -c "$SRC/mayhem/harnesses/$h.c" -o "build/fuzz/harness/$h.o"
  $CC $SANITIZER_FLAGS $LIB_FUZZING_ENGINE "build/fuzz/harness/$h.o" build/fuzz/harness/lsan_off.o \
      build/fuzz/libminiupnpc.a -o "$SRC/$h"
  $CC -O1 $SANITIZER_FLAGS $DEBUG_FLAGS -I include -I src -I build/repro \
      -c "$SRC/mayhem/harnesses/$h.c" -o "build/repro/harness/$h.o"
  $CC $SANITIZER_FLAGS "build/repro/harness/$h.o" build/repro/harness/standalone_main.o \
      build/fuzz/harness/lsan_off.o build/repro/libminiupnpc.a -o "$SRC/$h-standalone"
done
