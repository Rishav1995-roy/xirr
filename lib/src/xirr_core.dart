import 'dart:math' as math;

import 'cash_flow.dart';
import 'dates.dart';
import 'day_count.dart';
import 'exceptions.dart';
import 'numerics.dart' as nm;
import 'options.dart';

/// Net present value of [flows] at the annual [rate], using actual dates.
///
/// For every flow `a_i` on date `d_i`, with `d_0` the earliest date:
///
/// ```text
/// XNPV = sum( a_i / (1 + rate) ^ t_i )      t_i = years(d_0 -> d_i)
/// ```
///
/// where `years` is given by [dayCount] (default [DayCount.actual365], i.e.
/// `days / 365`, exactly as Excel's `XNPV`). With the default, `xnpv` agrees
/// with Excel. The XIRR is the [rate] for which this is zero.
///
/// By default flows are discounted to the earliest flow date. Pass [asOf] to
/// discount to another day instead (flows before it are compounded forward).
/// An empty list gives `0`.
///
/// [rate] is a fraction (`0.1` = 10 %) and must be greater than `-1`, otherwise
/// [ArgumentError] is thrown. A [CashFlow] with a non-finite amount throws
/// [InvalidCashFlowException].
double xnpv(
  double rate,
  Iterable<CashFlow> flows, {
  DayCount dayCount = DayCount.actual365,
  DateTime? asOf,
}) {
  if (rate.isNaN || rate <= -1) {
    throw ArgumentError.value(rate, 'rate', 'must be greater than -1');
  }
  final list = _validated(flows);
  if (list.isEmpty) return 0.0;
  var base = list.first.date;
  for (final f in list) {
    if (f.date.isBefore(base)) base = f.date;
  }
  final origin = asOf == null ? base : dateOnly(asOf);
  final x = nm.log1p(rate);
  var total = 0.0;
  for (final f in list) {
    total += f.amount * math.exp(-dayCount.yearFraction(origin, f.date) * x);
  }
  return total;
}

/// Annualised internal rate of return of irregularly dated [flows].
///
/// Finds the rate `r` that makes [xnpv] zero:
///
/// ```text
/// sum( a_i / (1 + r) ^ ((d_i - d_0) / 365) ) = 0
/// ```
///
/// The result is a fraction: `0.1234` means 12.34 %. With default [options]
/// the result matches Excel's `XIRR`.
///
/// Flows are sorted by date, flows on the same day are added together, and
/// zero amounts are ignored. When several rates satisfy the equation (possible
/// when the sign of the flows changes more than once) the one closest to
/// `options.guess` is returned.
///
/// Throws an [XirrException]:
/// * [InvalidCashFlowException] for a `NaN` or infinite amount,
/// * [InsufficientCashFlowsException] for fewer than two usable flows,
/// * [NoSignChangeException] if all flows have the same sign,
/// * [NonConvergenceException] if no rate in `[options.minRate,
///   options.maxRate]` could be found.
///
/// Throws [ArgumentError] for invalid [options]. Use [tryXirr] to get `null`
/// instead of an exception, or [xirrDetailed] for diagnostics.
double xirr(
  Iterable<CashFlow> flows, {
  XirrOptions options = const XirrOptions(),
}) {
  final r = xirrDetailed(flows, options: options);
  if (!r.converged) {
    throw NonConvergenceException(
      'No rate between ${options.minRate} and ${options.maxRate} satisfied '
      'the cash flows using ${options.method.name} '
      '(${r.iterations} iterations).',
      iterations: r.iterations,
      lastEstimate: r.rate.isFinite ? r.rate : null,
    );
  }
  return r.rate;
}

/// Like [xirr] but returns `null` instead of throwing an [XirrException].
///
/// Invalid [options] still throw [ArgumentError], because that is a
/// programming error and not a property of the data.
double? tryXirr(
  Iterable<CashFlow> flows, {
  XirrOptions options = const XirrOptions(),
}) {
  try {
    return xirr(flows, options: options);
  } on XirrException {
    return null;
  }
}

/// Like [xirr] but returns an [XirrResult] with diagnostics instead of only
/// the rate.
///
/// Bad input still throws ([InvalidCashFlowException],
/// [InsufficientCashFlowsException], [NoSignChangeException]). A failure to
/// find a root does **not** throw here: it returns `converged: false`.
XirrResult xirrDetailed(
  Iterable<CashFlow> flows, {
  XirrOptions options = const XirrOptions(),
}) {
  options.validate();
  final series = _prepare(flows, options.dayCount);
  final x0 = nm.log1p(options.guess);
  final xLo = nm.log1p(options.minRate);
  final xHi = nm.log1p(options.maxRate);
  final tol = options.tolerance;
  final maxIter = options.maxIterations;

  nm.SolveOutcome outcome;
  var used = options.method;
  var iterations = 0;

  switch (options.method) {
    case SolverMethod.newton:
      outcome = nm.newton(series, x0, xLo, xHi, tol, maxIter);
    case SolverMethod.auto:
      // Newton either converges within a few dozen steps or is not the right
      // tool (flat or exponential-like regions); do not burn the whole budget.
      final first = nm.newton(series, x0, xLo, xHi, tol, math.min(maxIter, 50));
      if (first.converged && series.relativeResidual(first.x) < 1e-7) {
        outcome = first;
        used = SolverMethod.newton;
      } else {
        iterations = first.iterations;
        used = SolverMethod.brent;
        outcome = _bracketed(
            series, SolverMethod.brent, x0, xLo, xHi, tol, maxIter, first.x);
      }
    case SolverMethod.brent:
    case SolverMethod.bisection:
      outcome = _bracketed(
          series, options.method, x0, xLo, xHi, tol, maxIter, double.nan);
  }
  iterations += outcome.iterations;
  final x = outcome.x;
  final rate = x.isFinite ? nm.expm1(x) : double.nan;
  return XirrResult(
    rate: rate,
    iterations: iterations,
    method: used,
    converged: outcome.converged && rate.isFinite,
    residual: x.isFinite ? series.npv(x) : double.nan,
    cashFlowCount: series.length,
  );
}

nm.SolveOutcome _bracketed(
  nm.Series series,
  SolverMethod method,
  double x0,
  double xLo,
  double xHi,
  double tol,
  int maxIter,
  double fallbackX,
) {
  final bracket = nm.findBracket(series, x0, xLo, xHi);
  if (bracket == null) {
    return nm.SolveOutcome(x: fallbackX, converged: false, iterations: 0);
  }
  return method == SolverMethod.bisection
      ? nm.bisection(series, bracket, tol, maxIter)
      : nm.brent(series, bracket, tol, maxIter);
}

List<CashFlow> _validated(Iterable<CashFlow> flows) {
  final list = flows.toList(growable: false);
  for (var i = 0; i < list.length; i++) {
    if (!list[i].amount.isFinite) {
      throw InvalidCashFlowException(i, list[i].amount);
    }
  }
  return list;
}

/// Validates, sorts, merges same-day flows and builds the solver series.
nm.Series _prepare(Iterable<CashFlow> flows, DayCount dayCount) {
  final sorted = _validated(flows).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final dates = <DateTime>[];
  final amounts = <double>[];
  for (final f in sorted) {
    if (dates.isNotEmpty && dates.last == f.date) {
      amounts[amounts.length - 1] += f.amount;
    } else {
      dates.add(f.date);
      amounts.add(f.amount);
    }
  }
  final keptDates = <DateTime>[];
  final keptAmounts = <double>[];
  var hasPositive = false;
  var hasNegative = false;
  for (var i = 0; i < dates.length; i++) {
    final a = amounts[i];
    if (a == 0) continue;
    keptDates.add(dates[i]);
    keptAmounts.add(a);
    if (a > 0) {
      hasPositive = true;
    } else {
      hasNegative = true;
    }
  }
  if (keptDates.length < 2) {
    throw InsufficientCashFlowsException(keptDates.length);
  }
  if (!hasPositive || !hasNegative) {
    throw NoSignChangeException(onlyPositive: hasPositive);
  }
  final base = keptDates.first;
  final times = List<double>.generate(
    keptDates.length,
    (i) => dayCount.yearFraction(base, keptDates[i]),
    growable: false,
  );
  return nm.Series(times, keptAmounts);
}
