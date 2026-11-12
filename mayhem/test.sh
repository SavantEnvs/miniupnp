#!/usr/bin/env bash
#
# mayhem/test.sh — RUN this repo's OWN functional test suite (already built by mayhem/build.sh).
# exit 0 = pass. EDIT per repo. PATCH-grade oracle: after an agent patches the source, the grader
# rebuilds (build.sh) then runs this. DELETE this file if the repo has no meaningful tests.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC/miniupnpc"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

B=build/test
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
passed=0 failed=0

# check <name> <command...>: passes iff the command succeeds.
check() {
  local name="$1"; shift
  if "$@"; then passed=$((passed+1)); else echo "FAIL: $name" >&2; failed=$((failed+1)); fi
}
has() { grep -qF -- "$2" <<<"$1"; }
runner() { [ -x "$B/$1" ] || { echo "missing $B/$1: mayhem/build.sh must build it" >&2; exit 2; }; }
for r in minixmlvalid testupnpreplyparse testigddescparse testportlistingparse testaddr_is_reserved; do runner "$r"; done

# minixml: upstream's validation emits one event per element/attribute/data item.
out="$("$B/minixmlvalid" 2>&1)"; rc=$?
check "minixmlvalid exit" test "$rc" -eq 0
check "minixmlvalid event count" has "$out" "17 events"

# upnpreplyparse: every reply must produce its recorded name/value pairs; a wrong expectation must be rejected.
for x in testreplyparse/*.xml; do
  "$B/testupnpreplyparse" "$x" "${x%.xml}.namevalue" >/dev/null 2>&1
  check "replyparse $x" test $? -eq 0
done
printf 'NewExternalIPAddress=not.the.address\n' > "$tmp/wrong.namevalue"
"$B/testupnpreplyparse" testreplyparse/GetExternalIPAddress.xml "$tmp/wrong.namevalue" >/dev/null 2>&1
check "replyparse rejects a wrong value" test $? -ne 0

# igddescparse: parsed control URLs for two real device descriptions.
out="$("$B/testigddescparse" testdesc/new_LiveBox_desc.xml testdesc/new_LiveBox_desc.values 2>&1)"; rc=$?
check "igddescparse LiveBox exit" test "$rc" -eq 0
check "igddescparse LiveBox controlURL" has "$out" "controlURL='http://fake/87895a19/upnp/control/WANIPConn1'"
out="$("$B/testigddescparse" testdesc/linksys_WAG200G_desc.xml testdesc/linksys_WAG200G_desc.values 2>&1)"; rc=$?
check "igddescparse linksys exit" test "$rc" -eq 0
check "igddescparse linksys prints urls" has "$out" "controlURL='"

# portlistingparse: three port mappings parsed from a fixed reply.
out="$("$B/testportlistingparse" 2>&1)"; rc=$?
check "portlistingparse exit" test "$rc" -eq 0
check "portlistingparse first mapping" has "$out" "0 TCP 12345->192.168.1.137:12345 'dooom A' '134.231.2.11' 347"
check "portlistingparse udp mapping" has "$out" "2 UDP  5002->192.168.1.123:4001  'xxx' '' 0"
check "portlistingparse verdict" has "$out" "test of portlistingparse OK"

# addr_is_reserved: known classifications.
out="$("$B/testaddr_is_reserved" 2>&1)"; rc=$?
check "addr_is_reserved exit" test "$rc" -eq 0
check "addr_is_reserved private" has "$out" "testing 192.168.1.1 1 1"
check "addr_is_reserved public" has "$out" "testing 8.8.8.8 0 0"
check "addr_is_reserved CGNAT edge" has "$out" "testing 100.128.1.1 0 0"

emit_ctrf "miniupnpc-validate" "$passed" "$failed" 0
