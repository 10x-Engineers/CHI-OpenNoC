#!/usr/bin/env bash
# =============================================================================
# tools/link_check.sh -- run rtl/tb/tb_hnf_link.sv, the Chapter 14 link-activation
# check for hnf.v.
#
#   ./tools/link_check.sh          run under xrun (Xcelium)
#   SIM=vcs ./tools/link_check.sh  run under VCS
#
# The bench drives the peer half of the HN-F's CHI link and judges:
#   Table 14-2 STOP/ACTIVATE (p.14-450, MUST) -- no credit before LINKACTIVEACK,
#   Sec 14.2.1 (p.14-445)                     -- at most 15 outstanding,
#   Table 14-2 DEACTIVATE (p.14-450, MUST)    -- LINKACTIVEACK held until every
#                                                credit is back, and the pool
#                                                refills for a re-activation.
#
# Not part of tools/lint.sh: it needs a licensed simulator. Verilator cannot run
# it -- 5.048 segfaults constructing the HN-F model, inside VL_MURMUR64_HASH in
# ctor_var_reset, before any Verilog executes.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../rtl" || exit 2

SIM=${SIM:-xrun}
command -v "$SIM" >/dev/null || { echo "$SIM not on PATH"; exit 2; }

# chi_ring_channel.v and xp_sel_bit_from_vec.v declare parameters with no default,
# which xrun rejects, and the HN-F needs neither -- so name the misc modules it
# does need rather than globbing.
MISC="misc/hnf_biq.v misc/poll_function.v misc/poll_with_start_entry.v
      misc/sync_fifo.v misc/chi_link_handshake.v"
OUT=$(mktemp -d)

case "$SIM" in
  xrun) CMD=(xrun -sv -incdir include -top tb_hnf_link -xmlibdirname "$OUT/xcelium.d") ;;
  vcs)  CMD=(vcs  -sverilog +incdir+include -top tb_hnf_link -R -Mdir="$OUT/csrc" -o "$OUT/simv") ;;
  *)    echo "unsupported SIM=$SIM"; exit 2 ;;
esac

# shellcheck disable=SC2086
"${CMD[@]}" tb/tb_hnf_link.sv src/hnf/*.v $MISC > "$OUT/sim.log" 2>&1
grep -E "^(FAIL|tb_hnf_link:)" "$OUT/sim.log" | sed 's/^/  /'

if grep -q "tb_hnf_link: PASSED" "$OUT/sim.log"; then
  rm -rf "$OUT"; echo "link check OK"; exit 0
fi
echo "link check FAILED -- full log: $OUT/sim.log"
grep -E "\*E,|\*F," "$OUT/sim.log" | head -10
exit 1
