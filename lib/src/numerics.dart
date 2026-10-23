// ignore_for_file: public_member_api_docs
// Internal numerical kernels; not part of the public API.

import 'dart:math' as math;

const double _eps = 2.220446049250313e-16;

/// `log(1 + x)`, accurate for tiny `x` (Kahan's trick; `dart:math` has no
/// `log1p`).
double log1p(double x) {
  final u = 1.0 + x;
  if (u == 1.0) return x;
  return math.log(u) * x / (u - 1.0);
}

/// `exp(x) - 1`, accurate for tiny `x` (`dart:math` has no `expm1`).
double expm1(double x) {
  final u = math.exp(x);
  if (u == 1.0) return x;
  final um1 = u - 1.0;
  if (um1 == -1.0) return -1.0;
  if (u.isInfinite) return u;
  return um1 * x / math.log(u);
}

/// Outcome of one solver attempt, expressed in log space `x = ln(1 + rate)`.
class SolveOutcome {
  const SolveOutcome({
    required this.x,
    required this.converged,
    required this.iterations,
  });

  /// Final (or last) log-rate; `NaN` if nothing usable was produced.
  final double x;
  final bool converged;
  final int iterations;
}

/// A merged, sorted cash flow series, evaluated in log-rate space.
///
/// With `x = ln(1 + r)` the present value is `f(x) = sum a_i * exp(-t_i * x)`.
/// To stay finite for long horizons and rates close to -100 %, the series is
/// multiplied by the positive factor `exp(s * x)` (`s = t_max` for `x < 0`,
/// `0` otherwise). That scaling never changes a root or the sign of `f`.
class Series {
  Series(this.times, this.amounts) : tMax = times.isEmpty ? 0.0 : times.last;

  final List<double> times;
  final List<double> amounts;
  final double tMax;

  int get length => times.length;

  /// Scaled value and the matching scaled derivative of the *unscaled*
  /// function, so that `f / d` is exactly the Newton step of the true NPV.
  (double, double) eval(double x) {
    final s = x < 0 ? tMax : 0.0;
    var f = 0.0;
    var d = 0.0;
    for (var i = 0; i < times.length; i++) {
      final e = amounts[i] * math.exp(-(times[i] - s) * x);
      f += e;
      d -= times[i] * e;
    }
    return (f, d);
  }

  /// Scaled value only.
  double value(double x) => eval(x).$1;

  /// |f| relative to the magnitude of its terms (0 = perfect root).
  double relativeResidual(double x) {
    final s = x < 0 ? tMax : 0.0;
    var f = 0.0;
    var mag = 0.0;
    for (var i = 0; i < times.length; i++) {
      final e = amounts[i] * math.exp(-(times[i] - s) * x);
      f += e;
      mag += e.abs();
    }
    return mag == 0 ? double.infinity : f.abs() / mag;
  }

  /// Unscaled net present value at [x] (what `xnpv` would return).
  double npv(double x) {
    var f = 0.0;
    for (var i = 0; i < times.length; i++) {
      f += amounts[i] * math.exp(-times[i] * x);
    }
    return f;
  }
}

/// Tolerance on `x` that corresponds to [tol] on the rate at `x`.
double _xTol(double tol, double x) {
  final scaled = tol / math.max(1.0, math.exp(x));
  return math.max(scaled, 4 * _eps * math.max(1.0, x.abs()));
}

/// Newton-Raphson from [x0], kept inside `[xLo, xHi]`.
SolveOutcome newton(
  Series series,
  double x0,
  double xLo,
  double xHi,
  double tol,
  int maxIter,
) {
  var x = x0;
  for (var i = 1; i <= maxIter; i++) {
    final (f, d) = series.eval(x);
    if (f == 0.0) return SolveOutcome(x: x, converged: true, iterations: i);
    if (!f.isFinite || !d.isFinite || d == 0.0) {
      return SolveOutcome(x: x, converged: false, iterations: i);
    }
    var step = f / d;
    if (step > 8) step = 8;
    if (step < -8) step = -8;
    final next = x - step;
    if (next < xLo || next > xHi) {
      return SolveOutcome(x: x, converged: false, iterations: i);
    }
    final dRate = (math.exp(next) - math.exp(x)).abs();
    final limit = math.max(tol, 4 * _eps * math.exp(next));
    x = next;
    if (dRate <= limit) {
      return SolveOutcome(x: x, converged: true, iterations: i);
    }
  }
  return SolveOutcome(x: x, converged: false, iterations: maxIter);
}

/// A pair of log-rates with a sign change of `f` between them.
class Bracket {
  const Bracket(this.lo, this.hi, this.fLo, this.fHi);
  final double lo;
  final double hi;
  final double fLo;
  final double fHi;
}

/// Walks outwards from [x0] in growing steps until `f` changes sign, so the
/// root nearest to the guess is found. Returns `null` if none exists in
/// `[xLo, xHi]`.
Bracket? findBracket(Series series, double x0, double xLo, double xHi) {
  final start = math.min(math.max(x0, xLo), xHi);
  final f0 = series.value(start);
  if (f0 == 0.0) return Bracket(start, start, 0.0, 0.0);
  if (f0.isNaN) return null;
  var left = start;
  var fLeft = f0;
  var right = start;
  var fRight = f0;
  var h = 0.05;
  while (left > xLo || right < xHi) {
    if (right < xHi) {
      final next = math.min(right + h, xHi);
      final fn = series.value(next);
      if (fn.isNaN) return null;
      if (fn == 0.0) return Bracket(next, next, 0.0, 0.0);
      if ((fn < 0) != (fRight < 0)) return Bracket(right, next, fRight, fn);
      right = next;
      fRight = fn;
    }
    if (left > xLo) {
      final next = math.max(left - h, xLo);
      final fn = series.value(next);
      if (fn.isNaN) return null;
      if (fn == 0.0) return Bracket(next, next, 0.0, 0.0);
      if ((fn < 0) != (fLeft < 0)) return Bracket(next, left, fn, fLeft);
      left = next;
      fLeft = fn;
    }
    h = math.min(h * 1.5, 2.0);
  }
  return null;
}

/// Brent's method (inverse quadratic interpolation + secant + bisection).
SolveOutcome brent(Series series, Bracket br, double tol, int maxIter) {
  if (br.lo == br.hi) {
    return SolveOutcome(x: br.lo, converged: true, iterations: 0);
  }
  var a = br.lo;
  var b = br.hi;
  var fa = br.fLo;
  var fb = br.fHi;
  var c = b;
  var fc = fb;
  var d = 0.0;
  var e = 0.0;
  for (var i = 1; i <= maxIter; i++) {
    if ((fb > 0 && fc > 0) || (fb < 0 && fc < 0)) {
      c = a;
      fc = fa;
      d = b - a;
      e = d;
    }
    if (fc.abs() < fb.abs()) {
      a = b;
      b = c;
      c = a;
      fa = fb;
      fb = fc;
      fc = fa;
    }
    final tol1 = 2 * _eps * b.abs() + 0.5 * _xTol(tol, b);
    final xm = 0.5 * (c - b);
    if (xm.abs() <= tol1 || fb == 0.0) {
      return SolveOutcome(x: b, converged: true, iterations: i);
    }
    if (e.abs() >= tol1 && fa.abs() > fb.abs()) {
      final s = fb / fa;
      double p;
      double q;
      if (a == c) {
        p = 2 * xm * s;
        q = 1 - s;
      } else {
        final qq = fa / fc;
        final r = fb / fc;
        p = s * (2 * xm * qq * (qq - r) - (b - a) * (r - 1));
        q = (qq - 1) * (r - 1) * (s - 1);
      }
      if (p > 0) q = -q;
      p = p.abs();
      final min1 = 3 * xm * q - (tol1 * q).abs();
      final min2 = (e * q).abs();
      if (2 * p < math.min(min1, min2)) {
        e = d;
        d = p / q;
      } else {
        d = xm;
        e = d;
      }
    } else {
      d = xm;
      e = d;
    }
    a = b;
    fa = fb;
    if (d.abs() > tol1) {
      b += d;
    } else {
      b += xm >= 0 ? tol1 : -tol1;
    }
    fb = series.value(b);
    if (fb.isNaN) return SolveOutcome(x: b, converged: false, iterations: i);
  }
  return SolveOutcome(x: b, converged: false, iterations: maxIter);
}

/// Plain bisection on a bracket.
SolveOutcome bisection(Series series, Bracket br, double tol, int maxIter) {
  if (br.lo == br.hi) {
    return SolveOutcome(x: br.lo, converged: true, iterations: 0);
  }
  var a = br.lo;
  var b = br.hi;
  final negativeAtLo = br.fLo < 0;
  var mid = 0.5 * (a + b);
  for (var i = 1; i <= maxIter; i++) {
    mid = 0.5 * (a + b);
    final fm = series.value(mid);
    if (fm == 0.0) return SolveOutcome(x: mid, converged: true, iterations: i);
    if ((fm < 0) == negativeAtLo) {
      a = mid;
    } else {
      b = mid;
    }
    if ((b - a) * 0.5 <= _xTol(tol, mid)) {
      return SolveOutcome(
        x: 0.5 * (a + b),
        converged: true,
        iterations: i,
      );
    }
  }
  return SolveOutcome(x: mid, converged: false, iterations: maxIter);
}
