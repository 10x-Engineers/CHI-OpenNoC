#!/usr/bin/env bash
# =============================================================================
# tools/lint.sh -- licence-free structural lint of every CHI node in this repo.
#
#   ./tools/lint.sh            lint all nodes
#   ./tools/lint.sh hnf snf    lint the named ones
#
# Verilator only: the repo's own flow needs VCS, which no CI runner has. This
# elaborates each node standalone and fails on ANY %Error or %Warning, so a PR
# that introduces a warning cannot be merged. Some of what that catches:
#
#   - %Warning-ALWNEVER -- an `always @*` whose right-hand sides are all constant,
#     so the inferred sensitivity list is empty and the block never runs. That
#     silently leaves the assigned bits X for the whole simulation, and it has
#     already been found three times in this repo (snf_data_buffer.sv,
#     hnf_link_txdat_wrap.sv, hni_data_buffer.sv).
#   - %Warning-COMBDLY -- a non-blocking assignment inside a combinational
#     process. Verilator executes it as blocking and VCS schedules an NBA
#     update, so the two tools disagree on the value inside the time step.
#   - %Warning-LATCH -- an incomplete `always @*`, which synthesises a latch
#     where combinational logic was intended.
#   - %Warning-CASEINCOMPLETE -- an uncovered case arm. Where the value really is
#     unreachable a `default` says so; where it is not, the output is wrong.
#   - %Warning-WIDTH* -- an implicit truncation or expansion. This is where a
#     truncated address, NodeID or entry index hides: the HN-I's region decode
#     compared a CHI address truncated to the AXI width against a full-width
#     region base until the gate was turned on.
#
# Narrow a width at the site that means it -- a part-select, a sized localparam,
# an explicit zero-extension -- never with a lint_off pragma, which hides the next
# one too.
#
# The behavioural counterpart is tools/link_check.sh, which needs a simulator this
# script deliberately does not.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../rtl" || exit 2

if [ "$#" -gt 0 ]; then NODES=("$@"); else NODES=(hnf hni rni snf); fi

# The version CI installs. Verilator's warning set moves between releases, so a
# clean run under a different binary does not prove a clean run in CI: 5.020 also
# reports WIDTHEXPAND for a 1-bit operand widened into an N-bit arithmetic context,
# which 5.050 treats as noise. The WIDTHTRUNC and WIDTHCONCAT sets -- the ones where
# information is actually lost -- are identical between the two.
VERILATOR_PIN=5.050

command -v verilator >/dev/null || { echo "verilator not on PATH"; exit 2; }
verilator --version
# ALWNEVER is emitted only by Verilator 5.x. An older binary reports none and would
# pass this gate vacuously, which is worse than not running it at all.
MAJOR=$(verilator --version | sed -nE 's/^Verilator ([0-9]+).*/\1/p')
if [ -z "$MAJOR" ] || [ "$MAJOR" -lt 5 ]; then
  echo "FAIL: Verilator 5.0 or later required (ALWNEVER is not reported before 5.x)"
  exit 2
fi
VERSION=$(verilator --version | sed -nE 's/^Verilator ([0-9.]+).*/\1/p')
if [ "$VERSION" != "$VERILATOR_PIN" ]; then
  echo "NOTE: CI pins Verilator $VERILATOR_PIN, this is $VERSION -- the two report"
  echo "      different warning sets, so a pass here is not a pass in CI."
fi

rc=0

for n in "${NODES[@]}"; do
  echo "==================== $n ===================="
  out=$(verilator --lint-only -Wno-fatal --top-module "$n" \
          -Iinclude -Imisc -I"src/$n" src/"$n"/*.sv 2>&1)
  echo "$out" | grep -oE "^%(Error|Warning)-[A-Z0-9]+" | sort | uniq -c | sort -rn | sed 's/^/  /'

  if echo "$out" | grep -q "^%Error"; then
    echo "  FAIL: $n does not elaborate"
    echo "$out" | grep -A4 "^%Error" | head -40
    rc=1
  elif echo "$out" | grep -q "^%Warning"; then
    echo "  FAIL: $n has lint warnings"
    echo "$out" | grep -A4 "^%Warning" | head -60
    rc=1
  fi
done

echo
if [ $rc -eq 0 ]; then echo "lint OK"; else echo "lint FAILED"; fi
exit $rc
