#!/usr/bin/env python3
"""Reject a part-select that reads or writes past its operand once its enclosing
`for` loops are unrolled.

    ./tools/check_select_bounds.py -Iinclude -Isrc/hnf include/chie_pkg.sv src/hnf/*.sv

Every argument is passed straight to slang, so this takes the same include paths,
defines and file list as tools/lint.sh.

Why it exists: `a[b*8 +: 8]` inside `for (b = 0; b < 16; b++)` over a 64-bit `a`
is accepted by Verilator, slang and Xcelium -- IEEE 1800 makes an out-of-range
part-select with a variable base yield x rather than an error -- and rejected by
Verific, which constant-folds the unrolled index first. A design that depends on
which of those a tool does is not portable, and the difference is invisible in
simulation because the x is usually masked by a surrounding mux.
"""
import glob
import shlex
import sys
import tempfile
from pathlib import Path

try:
    import pyslang
    from pyslang import ast as A
except ImportError:
    sys.exit("pyslang is required: pip install pyslang")

#: Loops running longer than this are left alone rather than unrolled -- the check
#: is for hand-written byte loops, not for a state space.
MAX_UNROLL = 4096


def _int(expr, ctx):
    """The expression's value under `ctx`, or None where it is not constant."""
    try:
        v = expr.eval(ctx)
    except Exception:
        return None
    if v is None:
        return None
    try:
        return int(v.value)
    except Exception:
        return None


def _span(node):
    r = node.sourceRange
    return (r.start.buffer.id, r.start.offset, r.end.offset)


def unroll(loop, ctx):
    """The values `loop`'s variable takes, or None where it is not statically bounded."""
    loop_vars = list(loop.loopVars)
    if len(loop_vars) != 1 or loop_vars[0].initializer is None:
        return None
    var = loop_vars[0]
    init = var.initializer.eval(ctx)
    if init is None:
        return None
    ctx.createLocal(var, init)

    values = []
    for _ in range(MAX_UNROLL):
        keep = _int(loop.stopExpr, ctx)
        if keep is None:
            return None
        if not keep:
            return values
        got = ctx.findLocal(var)
        if got is None:
            return None
        values.append(int(got.value))
        for step in loop.steps:
            try:
                step.eval(ctx)
            except Exception:
                return None
    return None


def select_bounds(sel, ctx):
    """(low, high) bit indices this select names, or None where not constant."""
    if isinstance(sel, A.ElementSelectExpression):
        i = _int(sel.selector, ctx)
        return None if i is None else (i, i)
    left = _int(sel.left, ctx)
    right = _int(sel.right, ctx)
    if left is None or right is None:
        return None
    kind = sel.selectionKind
    if kind == A.RangeSelectionKind.Simple:
        return (min(left, right), max(left, right))
    if kind == A.RangeSelectionKind.IndexedUp:
        return (left, left + right - 1)
    return (left - right + 1, left)


def where(sm, loc):
    return f"{sm.getFileName(loc)}:{sm.getLineNumber(loc)}:{sm.getColumnNumber(loc)}"


def contains(outer, inner):
    ob, os_, oe = _span(outer)
    ib, is_, ie = _span(inner)
    return ob == ib and os_ <= is_ and ie <= oe


def reachable(sel, conds, ctx):
    """False where a statically-taken branch of an enclosing `if` excludes `sel`."""
    for stmt in conds:
        if not contains(stmt, sel):
            continue
        taken = None
        for cond in stmt.conditions:
            v = _int(cond.expr, ctx)
            if v is None:
                taken = None
                break
            taken = bool(v) if taken is None else (taken and bool(v))
        if taken is None:
            continue
        branch = stmt.ifTrue if taken else stmt.ifFalse
        other = stmt.ifFalse if taken else stmt.ifTrue
        if other is not None and contains(other, sel) and not (
                branch is not None and contains(branch, sel)):
            return False
    return True


def collect(node, kinds):
    out = []
    node.visit(lambda n: out.append(n) if isinstance(n, kinds) else None)
    return out


def scope_symbols(root):
    return collect(root, (A.ProceduralBlockSymbol, A.SubroutineSymbol))


def check_scope(scope, sm, violations):
    body = getattr(scope, "body", None)
    if body is None:
        return
    loops = collect(body, (A.ForLoopStatement,))
    if not loops:
        return
    selects = collect(body, (A.RangeSelectExpression, A.ElementSelectExpression))
    if not selects:
        return
    conds = collect(body, (A.ConditionalStatement,))

    ctx = A.EvalContext(scope)
    ctx.pushEmptyFrame()

    for loop in loops:
        values = unroll(loop, ctx)
        if not values:
            continue
        var = list(loop.loopVars)[0]
        for sel in [s for s in selects if contains(loop, s)]:
            operand = sel.value.type
            if not operand.hasFixedRange:
                continue
            rng = operand.fixedRange
            lo, hi = min(rng.left, rng.right), max(rng.left, rng.right)
            for value in values:
                ctx.createLocal(var, pyslang.SVInt(var.type.bitWidth, value, False))
                if not reachable(sel, conds, ctx):
                    continue
                bounds = select_bounds(sel, ctx)
                if bounds is None:
                    continue
                if bounds[0] < lo or bounds[1] > hi:
                    violations.add((where(sm, sel.sourceRange.start), str(operand),
                                    bounds, (hi, lo), var.name, value))
                    break


def scan(args):
    """Violations over the sources `args` names, or None where slang would not build."""
    expanded = []
    for a in args:
        expanded += sorted(glob.glob(a)) if any(c in a for c in "*?") else [a]

    driver = pyslang.driver.Driver()
    driver.addStandardArgs()
    cmd = " ".join(shlex.quote(a) for a in ["check_select_bounds"] + expanded)
    if not driver.parseCommandLine(cmd):
        return None
    if not driver.processOptions() or not driver.parseAllSources():
        return None
    compilation = driver.createCompilation()
    driver.reportCompilation(compilation, True)
    if driver.diagEngine.numErrors:
        return None

    violations = set()
    for scope in scope_symbols(compilation.getRoot()):
        check_scope(scope, driver.sourceManager, violations)
    return violations


#: Each case is (name, source, expected violation count). The zero-violation cases
#: are the ones that matter as much as the positive: a gate that reports the guarded
#: `[i-1]` below is one a reader disables, and then it catches nothing at all.
SELF_TEST = [
    ("past_operand", """
module t_past (input logic [63:0] a, output logic [127:0] o);
  always_comb begin
    o = '0;
    for (int unsigned b = 0; b < 16; b = b + 1)
      o[b*8 +: 8] = a[b*8 +: 8];
  end
endmodule
""", 1),
    ("guarded_by_index", """
module t_guard (input logic [7:0] v, output logic [7:0] o);
  always_comb begin
    for (int i = 0; i < 8; i = i + 1)
      if (i == 0) o[i] = v[i];
      else        o[i] = o[i-1] | v[i];
  end
endmodule
""", 0),
    ("masked_base", """
module t_mask (input logic [63:0] a, input int unsigned off, output logic [63:0] o);
  always_comb begin
    o = '0;
    for (int unsigned b = 0; b < 16; b = b + 1)
      o[((off + b) & 63)*8 +: 8] = a[((off + b) & 63)*8 +: 8];
  end
endmodule
""", 0),
]


def self_test():
    rc = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name, source, expected in SELF_TEST:
            path = Path(tmp) / f"{name}.sv"
            path.write_text(source)
            got = scan([str(path)])
            n = -1 if got is None else len(got)
            ok = n == expected
            rc |= 0 if ok else 1
            print(f"  {'ok  ' if ok else 'FAIL'} {name}: {n} violation(s), expected {expected}")
    print("self-test OK" if rc == 0 else "SELF-TEST FAILED -- the gate no longer reports what it claims to")
    return rc


def main(argv):
    if argv and argv[0] == "--self-test":
        return self_test()

    violations = scan(argv)
    if violations is None:
        return 2
    for site, operand, (blo, bhi), (hi, lo), var, value in sorted(violations):
        print(f"{site}: select [{bhi}:{blo}] is outside {operand} [{hi}:{lo}] "
              f"when {var} = {value}")
    if violations:
        print(f"FAIL: {len(violations)} out-of-range select(s) after loop unrolling")
        return 1
    print("select bounds OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
