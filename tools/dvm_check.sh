#!/usr/bin/env bash
# DVMOp error-completion check for the two Homes (rtl/tb/tb_{hnf,hni}_dvm.sv).
#
#   SIM=verilator ./tools/dvm_check.sh   # no licence needed
#   ./tools/dvm_check.sh                 # Xcelium
#   SIM=vcs ./tools/dvm_check.sh         # VCS
#
# Neither Home is an MN, so each answers a DVMOp with Sec 2.3.7's (p.2-75)
# structure and an NDERR Comp; the bench judges that structure.
set -uo pipefail
cd "$(dirname "$0")/../rtl" || exit 2

SIM=${SIM:-xrun}
command -v "$SIM" >/dev/null || { echo "$SIM not on PATH"; exit 2; }
if [ "$SIM" = verilator ]; then
  export OBJCACHE="${OBJCACHE-}"
  CXX=${CXX:-g++}
  echo 'int main(){}' | "$CXX" -std=c++20 -fcoroutines -x c++ - -o /dev/null 2>/dev/null || {
    echo "$CXX does not support -fcoroutines -- Verilator's --timing needs GCC >= 10 or Clang >= 14."
    exit 2
  }
fi

MISC="misc/poll_function.sv misc/poll_with_start_entry.sv misc/sync_fifo.sv
      misc/chi_link_handshake.sv misc/chie_flit_opt_check.sv"
declare -A SRCS=(
  [tb_hnf_dvm]="include/chie_pkg.sv include/opennoc_hnf_pkg.sv tb/tb_hnf_dvm.sv src/hnf/*.sv misc/hnf_biq.sv $MISC"
  [tb_hni_dvm]="include/chie_pkg.sv tb/tb_hni_dvm.sv src/hni/*.sv misc/assert_checker.sv $MISC"
)

rc=0
for top in tb_hnf_dvm tb_hni_dvm; do
  OUT=$(mktemp -d)
  case "$SIM" in
    xrun)      CMD=(xrun -sv -incdir include -incdir tb -top "$top" -xmlibdirname "$OUT/xcelium.d") ;;
    vcs)       CMD=(vcs -sverilog +incdir+include +incdir+tb -top "$top" -R -Mdir="$OUT/csrc" -o "$OUT/simv") ;;
    verilator) CMD=(verilator --binary --timing -j 0 -Wno-fatal -Iinclude -Itb
                    --top-module "$top" --Mdir "$OUT/obj_dir" -o sim) ;;
    *)         echo "unsupported SIM=$SIM"; exit 2 ;;
  esac
  # shellcheck disable=SC2086
  "${CMD[@]}" ${SRCS[$top]} > "$OUT/sim.log" 2>&1
  if [ "$SIM" = verilator ] && [ -x "$OUT/obj_dir/sim" ]; then
    "$OUT/obj_dir/sim" >> "$OUT/sim.log" 2>&1
  fi
  grep -E "^(FAIL|$top:)" "$OUT/sim.log" | sed 's/^/  /'
  if grep -q "$top: PASSED" "$OUT/sim.log"; then
    rm -rf "$OUT"
  else
    echo "$top FAILED -- full log: $OUT/sim.log"; rc=1
  fi
done
[ $rc -eq 0 ] && echo "dvm check OK"
exit $rc
