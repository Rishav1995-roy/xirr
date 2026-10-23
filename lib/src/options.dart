import 'day_count.dart';

/// Algorithm used to find the rate where the net present value is zero.
enum SolverMethod {
  /// Newton-Raphson from the guess; if it fails (zero slope, leaves the
  /// bounds, does not converge, or lands on a bad point) it falls back to
  /// [brent] automatically. This is the default: fast in the normal case,
  /// reliable in the hard ones.
  auto,

  /// Plain Newton-Raphson. Very fast near the answer but can diverge from a
  /// poor guess. Fails with `NonConvergenceException` instead of falling back.
  newton,

  /// Brent's method on an automatically found bracket. Guaranteed to converge
  /// once a sign change is bracketed, usually in a handful of iterations.
  brent,

  /// Bisection on an automatically found bracket. Slowest but simplest and
  /// completely predictable (about one binary digit per iteration).
  bisection,
}

/// Tuning knobs for `xirr`, `tryXirr` and `xirrDetailed`.
///
/// Every field has a sensible default, so `const XirrOptions()` is Excel
/// compatible. Use [copyWith] to change a few:
///
/// ```dart
/// final opts = const XirrOptions().copyWith(
///   dayCount: DayCount.actualActual,
///   method: SolverMethod.brent,
///   tolerance: 1e-12,
/// );
/// ```
final class XirrOptions {
  /// Creates options. Values are validated when they are used; an invalid
  /// value makes the calculation throw [ArgumentError].
  const XirrOptions({
    this.guess = 0.1,
    this.tolerance = 1e-10,
    this.maxIterations = 100,
    this.dayCount = DayCount.actual365,
    this.method = SolverMethod.auto,
    this.minRate = -0.999999999,
    this.maxRate = 1e9,
  });

  /// Starting point for Newton-Raphson and centre of the bracket search, as a
  /// plain fraction (`0.1` = 10 %). Must lie in `[minRate, maxRate]`.
  /// Default `0.1`, like Excel.
  final double guess;

  /// The solution is accepted when the rate is pinned down to within this
  /// absolute amount (`1e-10` = 0.00000001 %). Must be positive. For rates
  /// above 1 000 000 % the limit of double precision applies instead.
  final double tolerance;

  /// Maximum solver iterations per attempt. Must be at least 1.
  final int maxIterations;

  /// How time between dates is measured. Default [DayCount.actual365].
  final DayCount dayCount;

  /// Which algorithm to use. Default [SolverMethod.auto].
  final SolverMethod method;

  /// Lowest rate the solver may consider. Must be above `-1` (a rate of
  /// `-100 %` would make every discount factor undefined). Default
  /// `-0.999999999`, i.e. just above -100 %.
  final double minRate;

  /// Highest rate the solver may consider. Default `1e9` (10^11 %). A
  /// solution above this is reported as not converged.
  final double maxRate;

  /// Returns a copy with the given fields replaced.
  XirrOptions copyWith({
    double? guess,
    double? tolerance,
    int? maxIterations,
    DayCount? dayCount,
    SolverMethod? method,
    double? minRate,
    double? maxRate,
  }) =>
      XirrOptions(
        guess: guess ?? this.guess,
        tolerance: tolerance ?? this.tolerance,
        maxIterations: maxIterations ?? this.maxIterations,
        dayCount: dayCount ?? this.dayCount,
        method: method ?? this.method,
        minRate: minRate ?? this.minRate,
        maxRate: maxRate ?? this.maxRate,
      );

  /// Throws [ArgumentError] if any value is unusable.
  void validate() {
    if (!minRate.isFinite || minRate <= -1) {
      throw ArgumentError.value(minRate, 'minRate', 'must be finite and > -1');
    }
    if (!maxRate.isFinite || maxRate <= minRate) {
      throw ArgumentError.value(
        maxRate,
        'maxRate',
        'must be finite and greater than minRate',
      );
    }
    if (!guess.isFinite || guess < minRate || guess > maxRate) {
      throw ArgumentError.value(
        guess,
        'guess',
        'must be within [minRate, maxRate]',
      );
    }
    if (!tolerance.isFinite || tolerance <= 0) {
      throw ArgumentError.value(tolerance, 'tolerance', 'must be positive');
    }
    if (maxIterations < 1) {
      throw ArgumentError.value(maxIterations, 'maxIterations', 'must be >= 1');
    }
  }

  @override
  String toString() => 'XirrOptions(guess: $guess, tolerance: $tolerance, '
      'maxIterations: $maxIterations, dayCount: ${dayCount.name}, '
      'method: ${method.name}, minRate: $minRate, maxRate: $maxRate)';
}

/// Diagnostics returned by `xirrDetailed`.
final class XirrResult {
  /// Creates a result.
  const XirrResult({
    required this.rate,
    required this.iterations,
    required this.method,
    required this.converged,
    required this.residual,
    required this.cashFlowCount,
  });

  /// The annual rate as a fraction (`0.12` = 12 %). `NaN` if no estimate
  /// could be produced at all; otherwise only trustworthy when [converged].
  final double rate;

  /// Solver iterations used (all attempts together when `auto` fell back).
  final int iterations;

  /// The algorithm that produced [rate]. Never [SolverMethod.auto]: it reports
  /// `newton` or `brent` depending on which one finished the job.
  final SolverMethod method;

  /// Whether a root within the tolerance was found.
  final bool converged;

  /// The net present value at [rate], in the currency of the cash flows. Close
  /// to zero for a converged result. `NaN` when [rate] is `NaN`.
  final double residual;

  /// Number of cash flows that took part after merging same-day flows and
  /// dropping zero amounts.
  final int cashFlowCount;

  @override
  String toString() => 'XirrResult(rate: $rate, converged: $converged, '
      'iterations: $iterations, method: ${method.name}, '
      'residual: $residual, cashFlowCount: $cashFlowCount)';
}
