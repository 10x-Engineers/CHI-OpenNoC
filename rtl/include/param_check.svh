`ifndef PARAM_CHECK_SVH
`define PARAM_CHECK_SVH

// A width parameter declared beside its count is kept equal to $clog2 of it by hand,
// so an override of one without the other truncates every index silently. The width
// defaults are derived; this refuses an explicit override that disagrees.
//
// Written in IEEE 1800 section 20.11's elaboration form rather than inside an
// `initial` block: verilator --lint-only, which tools/lint.sh is, evaluates the
// former and never runs the latter.
`define CHECK_DERIVED_WIDTH(NODE, NUM, WID, WHAT)                                          \
    if (WID != ((NUM > 1) ? $clog2(NUM) : 1))                                              \
        $fatal(1, `"NODE: WID=%0d cannot index NUM=%0d WHAT; the width is $clog2 of the count, so leave it at its default.`", \
               WID, NUM);

`endif
