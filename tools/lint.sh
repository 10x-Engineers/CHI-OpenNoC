#!/usr/bin/env bash
# =============================================================================
# tools/lint.sh -- licence-free structural lint of every CHI node in this repo.
#
#   ./tools/lint.sh            lint all nodes
#   ./tools/lint.sh hnf snf    lint the named ones
#
# Verilator only: the repo's own flow needs VCS, which no CI runner has. This
# elaborates each node standalone and gates on the two things that are always a
# defect rather than a style opinion:
#
#   - any %Error (the design does not elaborate)
#   - %Warning-ALWNEVER -- an `always @*` whose right-hand sides are all constant,
#     so the inferred sensitivity list is empty and the block never runs. That is
#     not a style point: it silently leaves the assigned bits X for the whole
#     simulation, and it has already been found three times in this repo
#     (snf_data_buffer.v, hnf_link_txdat_wrap.v, hni_data_buffer.v).
#
#   - %Warning-COMBDLY -- a non-blocking assignment inside a combinational
#     process. Verilator executes it as blocking and VCS schedules an NBA
#     update, so the two tools disagree on the value inside the time step.
#   - %Warning-LATCH -- an incomplete `always @*`, which synthesises a latch
#     where combinational logic was intended.
#   - %Warning-CASEINCOMPLETE -- an uncovered case arm. Where the value really is
#     unreachable a `default` says so; where it is not, the output is wrong.
#
# The WIDTH* population is tallied and printed but does not fail the run: those
# need per-site judgement, and bulk-adding casts would turn signal into silence.
# WIDTHTRUNC in particular is where a truncated address or NodeID would hide.
#
# The behavioural counterpart is tools/link_check.sh, which needs a simulator this
# script deliberately does not.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../rtl" || exit 2

if [ "$#" -gt 0 ]; then NODES=("$@"); else NODES=(hnf hni rni snf); fi

command -v verilator >/dev/null || { echo "verilator not on PATH"; exit 2; }
verilator --version
# ALWNEVER is emitted only by Verilator 5.x. An older binary reports none and would
# pass this gate vacuously, which is worse than not running it at all.
MAJOR=$(verilator --version | sed -nE 's/^Verilator ([0-9]+).*/\1/p')
if [ -z "$MAJOR" ] || [ "$MAJOR" -lt 5 ]; then
  echo "FAIL: Verilator 5.0 or later required (ALWNEVER is not reported before 5.x)"
  exit 2
fi

FATAL="ALWNEVER|COMBDLY|LATCH|CASEINCOMPLETE"
rc=0

for n in "${NODES[@]}"; do
  echo "==================== $n ===================="
  out=$(verilator --lint-only -Wno-fatal --top-module "$n" \
          -Iinclude -Imisc -I"src/$n" src/"$n"/*.v 2>&1)
  echo "$out" | grep -oE "^%(Error|Warning)-[A-Z0-9]+" | sort | uniq -c | sort -rn | sed 's/^/  /'

  if echo "$out" | grep -q "^%Error"; then
    echo "  FAIL: $n does not elaborate"
    echo "$out" | grep -A4 "^%Error" | head -40
    rc=1
  fi
  # -E, not plain grep: FATAL is an alternation, and BRE would read the `|` as a
  # literal and pass vacuously on every node.
  if echo "$out" | grep -qE "%Warning-($FATAL)"; then
    echo "  FAIL: $n has a gated warning ($FATAL)"
    echo "$out" | grep -EA2 "%Warning-($FATAL)"
    rc=1
  fi
done

echo
if [ $rc -eq 0 ]; then echo "lint OK"; else echo "lint FAILED"; fi
exit $rc
