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
# Verilator is not the whole gate. tools/check_select_bounds.py runs beside it on
# the same file set, because the one class Verilator cannot see is a part-select
# that reads past its operand only once an enclosing `for` loop is unrolled --
# IEEE 1800 makes a variable-base select yield x rather than an error, so Verilator,
# slang and Xcelium all accept it and Verific rejects it.
#
# The behavioural counterpart is tools/link_check.sh, which needs a simulator this
# script deliberately does not.
# =============================================================================
set -uo pipefail
TOOLS=$(cd "$(dirname "$0")" && pwd) || exit 2
RTL=$(cd "$TOOLS/../rtl" && pwd) || exit 2
cd "$RTL" || exit 2

ALL_NODES=(hnf hni rni rnf snf)
if [ "$#" -gt 0 ]; then NODES=("$@"); else NODES=("${ALL_NODES[@]}"); fi

# The version CI installs. Verilator's warning set moves between releases, so a
# clean run under a different binary does not prove a clean run in CI: 5.020 also
# reports WIDTHEXPAND for a 1-bit operand widened into an N-bit arithmetic context,
# which 5.050 treats as noise. The WIDTHTRUNC and WIDTHCONCAT sets -- the ones where
# information is actually lost -- are identical between the two.
VERILATOR_PIN=5.050

command -v verilator >/dev/null || { echo "verilator not on PATH"; exit 2; }

# The interpreter that has pyslang, which is not necessarily the one `python3`
# names. $PYTHON overrides; a missing module is a hard stop, since a gate that
# quietly skips is worse than one that is not there.
PYTHON=${PYTHON:-}
if [ -z "$PYTHON" ]; then
  for p in python3 python3.12 python3.11 python3.10; do
    command -v "$p" >/dev/null && "$p" -c "import pyslang" 2>/dev/null && { PYTHON=$p; break; }
  done
fi
[ -n "$PYTHON" ] || { echo "no python3 with pyslang (pip install pyslang) -- tools/check_select_bounds.py cannot run"; exit 2; }
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

# The select-bounds gate proves itself before it is believed: a clean report from a
# checker that has stopped reporting is the one outcome worse than not running it.
"$PYTHON" "$TOOLS/check_select_bounds.py" --self-test || rc=1

# The optional flit fields are `ifdef'd, so the default build compiles none of the
# code that carries them. Each node is linted twice: once as it ships, once with
# every optional field declared -- the second pass is the only one that reads those
# branches at all. Section 13.10.56 (p.13-441) permits 4/8/12/16/24/32 for RSVDC and
# lets REQ and DAT differ; section 11.3 (p.11-365) gives MPAM only 0 or 11.
OPT_DEFINES="-DCHIE_MPAM_PRESENT -DCHIE_REQ_RSVDC_WIDTH=8 -DCHIE_DAT_RSVDC_WIDTH=16"

# chie_pkg.sv is listed rather than left to -Iinclude: Verilator resolves a
# missing *module* from the include path by filename, but not a package. The
# design's own assertions ship gated off, so nothing compiled them until they were
# turned on here; DISPLAY_INFO stays off, being $display tracing rather than a check.
node_sources() {  # $1 node -- the file set both gates read
  local n="$1"
  echo "include/chie_pkg.sv \
        $([ -f "include/opennoc_${n}_pkg.sv" ] && echo "include/opennoc_${n}_pkg.sv") \
        misc/chie_flit_opt_check.sv src/$n/*.sv"
}

lint_node() {   # $1 node, $2 pass label, $3.. extra defines
  local n="$1" label="$2"; shift 2
  echo "-------------------- $n ($label) --------------------"
  local out
  out=$(verilator --lint-only -Wno-fatal --top-module "$n" \
          -DASSERT_CHECKER_ON -DDISPLAY_FATAL "$@" \
          -Iinclude -Imisc -I"src/$n" $(node_sources "$n") 2>&1)
  echo "$out" | grep -oE "^%(Error|Warning)-[A-Z0-9]+" | sort | uniq -c | sort -rn | sed 's/^/  /'

  if echo "$out" | grep -q "^%Error"; then
    echo "  FAIL: $n does not elaborate ($label)"
    echo "$out" | grep -A4 "^%Error" | head -40
    return 1
  elif echo "$out" | grep -q "^%Warning"; then
    echo "  FAIL: $n has lint warnings ($label)"
    echo "$out" | grep -A4 "^%Warning" | head -60
    return 1
  fi
  return 0
}

# slang resolves an uninstantiated module from a library directory rather than from
# the include path, so `-y misc` is what -Imisc is to Verilator.
bounds_node() {  # $1 node, $2 pass label, $3.. extra defines
  local n="$1" label="$2"; shift 2
  echo "-------------------- $n select bounds ($label) --------------------"
  "$PYTHON" "$TOOLS/check_select_bounds.py" --top "$n" \
      -DASSERT_CHECKER_ON -DDISPLAY_FATAL "$@" \
      -Iinclude -Imisc -I"src/$n" -y misc --libext .sv $(node_sources "$n")
}

for n in "${NODES[@]}"; do
  echo "==================== $n ===================="
  lint_node "$n" "default"          || rc=1
  lint_node "$n" "optional fields" $OPT_DEFINES || rc=1
  bounds_node "$n" "default"          || rc=1
  bounds_node "$n" "optional fields" $OPT_DEFINES || rc=1
  # The MSHR entry index and the QoS pool sizes are the only things sized from
  # HNF_MSHR_ENTRIES_NUM_PARAM, and the passes above only ever see its default. A
  # third HN-F elaboration off 32 is what reads the derived pool numbers at all.
  if [ "$n" = hnf ]; then
    lint_node   "$n" "MSHR entries 64" -GHNF_MSHR_ENTRIES_NUM_PARAM=64 || rc=1
    bounds_node "$n" "MSHR entries 64" -GHNF_MSHR_ENTRIES_NUM_PARAM=64 || rc=1
    lint_node   "$n" "MSHR entries 16" -GHNF_MSHR_ENTRIES_NUM_PARAM=16 || rc=1
    bounds_node "$n" "MSHR entries 16" -GHNF_MSHR_ENTRIES_NUM_PARAM=16 || rc=1
  fi
  # SS16.1 (p.16-471) makes Data_Width 128, 256 or 512. The SN-F, HN-I and RN-I
  # packetise by it (SNF_PKTS, HNI_PKTS, opennoc_rni_pkg PKT_CHUNKS), so they are
  # elaborated at the other two widths as well; every other node still refuses
  # anything but 256 (chie_flit_opt_check).
  if [ "$n" = snf ] || [ "$n" = hni ] || [ "$n" = rni ]; then
    for w in 128 512; do
      lint_node   "$n" "Data_Width $w" -DCHIE_DATA_WIDTH=$w || rc=1
      bounds_node "$n" "Data_Width $w" -DCHIE_DATA_WIDTH=$w || rc=1
    done
  fi
done

# The generated NoC. It is shipped to integrators (tools/mesh_generator/README.md)
# and edited like any other source, but no node references it and it lives outside
# rtl/, so -Imisc never resolved it and nothing here ever opened the file. Generated
# from the checked-in configs and held to the same zero-warning rule as the nodes,
# at both ends of SS16.1's (p.16-472) legal NodeID_Width range.
lint_noc() {   # $1 generator dir, $2 gen script, $3 config, $4 wrapper, $5 system, $6 channel, $7 node
  local dir="$1" gen="$2" cfg="$3" wrapper="$4" system="$5" ch="$6" nd="$7" w top out
  for w in 7 11; do
    ( cd "$TOOLS/$dir" && "$PYTHON" "$gen" -f "$cfg" >/dev/null ) || {
      echo "  FAIL: $gen did not generate"; return 1; }
    # The populated system is the fabric with an rnf on every RNF port, so it is
    # linted over the RN-F's own sources as well as the fabric's.
    for top in "$wrapper" "$system"; do
      echo "-------------------- $top (NodeID_Width=$w) --------------------"
      out=$(cd "$TOOLS/$dir" && verilator --lint-only -Wno-fatal --top-module "$top" \
              -DASSERT_CHECKER_ON -DDISPLAY_FATAL -DCHIE_NID_WIDTH=$w \
              -I../../rtl/include -I../../rtl/misc -I../../rtl/src/rnf -I. -y ../../rtl/misc \
              ../../rtl/include/chie_pkg.sv "../../rtl/misc/$ch" "$nd" "$wrapper.sv" \
              $([ "$top" = "$system" ] && echo ../../rtl/src/rnf/*.sv "$system.sv") 2>&1)
      echo "$out" | grep -oE "^%(Error|Warning)-[A-Z0-9]+" | sort | uniq -c | sort -rn | sed 's/^/  /'
      if echo "$out" | grep -qE "^%(Error|Warning)"; then
        echo "  FAIL: $top has lint errors or warnings (NodeID_Width=$w)"
        echo "$out" | grep -A4 -E "^%(Error|Warning)" | head -60
        return 1
      fi
    done
  done
  return 0
}

if "$PYTHON" -c "import jinja2" >/dev/null 2>&1; then
  echo "==================== generated NoC ===================="
  lint_noc mesh_generator ./mesh_gen.py mesh_2x2.json mesh_wrapper_2x2 mesh_system_2x2 \
           chi_xp_channel.sv chi_xp_node.sv || rc=1
  lint_noc ring_generator ./ring_gen.py ring_8.json ring_wrapper_8 ring_system_8 \
           chi_ring_channel.sv chi_ring_node.sv || rc=1
else
  echo "==================== generated NoC ===================="
  echo "  SKIPPED: the generators need jinja2 ($PYTHON -m pip install jinja2)"
  rc=1
fi

# rtl/tb/tb_xp_link.sv -- the crosspoint's Chapter 14 link-activation bench. It
# runs under Verilator, so it can be a gate here rather than a manual step.
# tb_hnf_link.sv is its HN-F counterpart and now runs under Verilator too
# (SIM=verilator tools/link_check.sh), but stays out of CI because it builds the
# whole HN-F. --binary needs a compiler with coroutine support for the bench's
# own timing controls.
run_xp_link() {
  echo "==================== crosspoint link activation ===================="
  local out d
  d=$(mktemp -d) || return 1
  # ccache cannot see through the precompiled header --binary compiles against, so
  # a layout change can be served stale objects and the binary aborts in malloc
  # before any Verilog runs. See tools/link_check.sh.
  export OBJCACHE="${OBJCACHE-}"
  out=$(cd "$d" && verilator --binary -Wno-fatal -DDISPLAY_FATAL \
          --top-module tb_xp_link \
          -I"$RTL/include" -I"$RTL/misc" -I"$TOOLS/mesh_generator" \
          "$RTL/include/chie_pkg.sv" "$RTL/misc/chi_xp_channel.sv" \
          "$TOOLS/mesh_generator/chi_xp_node.sv" "$RTL/tb/tb_xp_link.sv" \
          -o xplink 2>&1 && ./obj_dir/xplink 2>&1)
  echo "$out" | grep -E "^(PASS|FAIL|===)" | sed 's/^/  /'
  rm -rf "$d"
  if echo "$out" | grep -q "=== TB PASS ==="; then return 0; fi
  # Told apart rather than lumped together: a compiler without coroutines cannot
  # build the bench's timing controls at all, which is a toolchain gap and not an
  # RTL defect. CI's ubuntu-latest has one; an older local g++ may not.
  if echo "$out" | grep -q "fcoroutines"; then
    echo "  SKIPPED: this g++ has no coroutine support, so --binary cannot build"
    echo "           the bench's timing controls. Try a newer compiler, e.g."
    echo "           PATH=/opt/rh/gcc-toolset-11/root/usr/bin:\$PATH $0"
    return 0
  fi
  echo "  FAIL: tb_xp_link did not pass"
  echo "$out" | tail -20 | sed 's/^/  /'
  return 1
}

if command -v verilator >/dev/null; then
  run_xp_link || rc=1
fi

# chie_flit_opt_check's refusals are `initial`-block $fatals, which --lint-only
# never reaches: it elaborates but runs nothing, and an uninstantiated module under
# --top-module is simply dropped. So a node that never instantiates the check has
# no refusal at all and nothing above says so -- rnf.sv was in that state, and a
# CHIE_DATA_WIDTH=512 RN-F elaborated cleanly and then hung on its first read.
run_width_refusal() {
  echo "==================== Data_Width refusal ===================="
  local n rcw=0 out d
  for n in "${ALL_NODES[@]}"; do
    if grep -q "u_chie_flit_opt_check" "src/$n/$n.sv"; then
      echo "  $n instantiates chie_flit_opt_check"
    else
      echo "  FAIL: src/$n/$n.sv does not instantiate chie_flit_opt_check, so a"
      echo "        CHIE_DATA_WIDTH != 256 build of $n is accepted rather than refused."
      rcw=1
    fi
  done
  # The structural pass above cannot show the refusal actually firing, so one node
  # is built and run at 512. The RN-F is that node: it is the cheapest to build and
  # the one the instantiation was missing from. A build failure is reported as a
  # build failure -- "did not refuse" would accuse the RTL of a defect that is not
  # there, which is the conflation run_xp_link's coroutine arm also exists to avoid.
  d=$(mktemp -d) || return 1
  # ccache cannot see through --binary's precompiled header; same reason as run_xp_link.
  export OBJCACHE="${OBJCACHE-}"
  if ! out=$(verilator --binary -Wno-fatal -DDISPLAY_FATAL -DCHIE_DATA_WIDTH=512 \
               --top-module rnf -Iinclude -Imisc -Isrc/rnf --Mdir "$d/obj" -o sim \
               $(node_sources rnf) 2>&1); then
    echo "  FAIL: the CHIE_DATA_WIDTH=512 rnf build did not complete -- this is a"
    echo "        toolchain or elaboration failure, not a missing refusal."
    echo "$out" | tail -20 | sed 's/^/  /'
    rm -rf "$d"; return 1
  fi
  out=$("$d/obj/sim" 2>&1)
  rm -rf "$d"
  # Anchored on chie_flit_opt_check's own $fatal text, so nothing but that refusal
  # firing can satisfy the gate.
  if echo "$out" | grep -q "Section 16.1 (p.16-471) permits 128, 256 and 512"; then
    echo "  rnf refuses CHIE_DATA_WIDTH=512 at time zero"
  else
    echo "  FAIL: an rnf built at CHIE_DATA_WIDTH=512 ran without refusing"
    echo "$out" | tail -20 | sed 's/^/  /'
    rcw=1
  fi
  return $rcw
}

run_width_refusal || rc=1

echo
if [ $rc -eq 0 ]; then echo "lint OK"; else echo "lint FAILED"; fi
exit $rc
