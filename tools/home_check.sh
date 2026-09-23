#!/usr/bin/env bash
# Directed Home benches (rtl/tb/tb_{hnf,hni}_*.sv, peer in tb_home_peer.svh).
#
#   SIM=verilator ./tools/home_check.sh   # no licence needed
#   ./tools/home_check.sh                 # Xcelium
#   SIM=vcs ./tools/home_check.sh         # VCS
#
#   tb_{hnf,hni}_dvm  Sec 2.3.7 (p.2-75): neither Home is an MN, so a DVMOp is
#                     granted, takes its NCBWrData, and completes NDERR
#   tb_hnf_stash      Sec 9.4.6 (p.9-344): no Stash snoop to a target the HN-F
#                     declares unable to receive one, and no error
#   tb_hnf_mte        Sec 12.1 / 12.11.3: no TagOp downstream for memory that is
#                     not Normal WriteBack, and the Home's own TagMatch Fail
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
  [tb_hnf_mte]="include/chie_pkg.sv include/opennoc_hnf_pkg.sv tb/tb_hnf_mte.sv src/hnf/*.sv misc/hnf_biq.sv $MISC"
  [tb_hnf_stash]="include/chie_pkg.sv include/opennoc_hnf_pkg.sv tb/tb_hnf_stash.sv src/hnf/*.sv misc/hnf_biq.sv $MISC"
  [tb_hni_dvm]="include/chie_pkg.sv tb/tb_hni_dvm.sv src/hni/*.sv misc/assert_checker.sv $MISC"
)

rc=0
for top in tb_hnf_dvm tb_hni_dvm tb_hnf_stash tb_hnf_mte; do
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
[ $rc -eq 0 ] && echo "home check OK"
exit $rc
