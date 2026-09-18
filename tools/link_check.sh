#!/usr/bin/env bash
# =============================================================================
# tools/link_check.sh -- run rtl/tb/tb_hnf_link.sv, the Chapter 14 link-activation
# check for hnf.sv.
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

# Verilator compiles the model to C++ and needs coroutines for --timing. The
# system compiler on an older distribution (GCC 8 on RHEL 8) fails deep in the
# generated makefile with "unrecognized command line option -fcoroutines", which
# does not name its own cause -- so check it here instead.
if [ "$SIM" = verilator ]; then
  # Verilator compiles every translation unit with -include <prefix>__pch.h, so the
  # compiler reads the precompiled header and never opens the model headers behind
  # it. ccache hashes only what the compiler opens, so after the model's layout
  # changes it returns objects built against the OLD layout: the translation units
  # then disagree on the root object's size, `new` under-allocates it, and its own
  # constructor writes past the end -- a heap-corruption abort inside malloc before
  # any Verilog runs. Correctness over a warm cache; OBJCACHE=ccache still opts in.
  export OBJCACHE="${OBJCACHE-}"
  CXX=${CXX:-g++}
  echo 'int main(){}' | "$CXX" -std=c++20 -fcoroutines -x c++ - -o /dev/null 2>/dev/null || {
    echo "$CXX does not support -fcoroutines -- Verilator's --timing needs GCC >= 10 or Clang >= 14."
    echo "Set CXX, or put a newer toolchain first on PATH (e.g. scl enable gcc-toolset-13)."
    exit 2
  }
fi

# chi_ring_channel.sv and xp_sel_bit_from_vec.sv declare parameters with no default,
# which xrun rejects, and the HN-F needs neither -- so name the misc modules it
# does need rather than globbing.
MISC="misc/hnf_biq.sv misc/poll_function.sv misc/poll_with_start_entry.sv
      misc/sync_fifo.sv misc/chi_link_handshake.sv misc/chie_flit_opt_check.sv"
OUT=$(mktemp -d)

case "$SIM" in
  xrun) CMD=(xrun -sv -incdir include -top tb_hnf_link -xmlibdirname "$OUT/xcelium.d") ;;
  vcs)  CMD=(vcs  -sverilog +incdir+include -top tb_hnf_link -R -Mdir="$OUT/csrc" -o "$OUT/simv") ;;
  # -incdir resolves a missing *module* by filename but not a package, so the two
  # the bench's flit types come from are named rather than left to the path.
  # -Wno-fatal: tools/lint.sh is the warning gate, and it runs over src/ only --
  # the bench's own width warnings must not block a behavioural check.
  verilator) CMD=(verilator --binary --timing -j 0 -Wno-fatal -Iinclude
                  --top-module tb_hnf_link --Mdir "$OUT/obj_dir" -o sim) ;;
  *)    echo "unsupported SIM=$SIM"; exit 2 ;;
esac

# shellcheck disable=SC2086
"${CMD[@]}" include/chie_pkg.sv include/opennoc_hnf_pkg.sv tb/tb_hnf_link.sv src/hnf/*.sv $MISC > "$OUT/sim.log" 2>&1

# xrun and vcs -R elaborate and run in one command; Verilator emits a binary to run.
if [ "$SIM" = verilator ] && [ -x "$OUT/obj_dir/sim" ]; then
  "$OUT/obj_dir/sim" >> "$OUT/sim.log" 2>&1
fi
grep -E "^(FAIL|tb_hnf_link:)" "$OUT/sim.log" | sed 's/^/  /'

if grep -q "tb_hnf_link: PASSED" "$OUT/sim.log"; then
  rm -rf "$OUT"; echo "link check OK"; exit 0
fi
echo "link check FAILED -- full log: $OUT/sim.log"
grep -E "\*E,|\*F," "$OUT/sim.log" | head -10
exit 1
