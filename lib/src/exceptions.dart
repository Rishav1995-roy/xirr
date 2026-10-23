/// Base class of every error this package throws for bad input or a failed
/// calculation.
///
/// Catch `XirrException` to handle all of them, or one of the subclasses to
/// react to a specific problem. Programming mistakes such as an invalid
/// option value (for example a negative tolerance) throw [ArgumentError]
/// instead.
sealed class XirrException implements Exception {
  /// Creates an exception with a human readable [message].
  const XirrException(this.message);

  /// Description of what went wrong.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when there are fewer than two non-zero cash flows once flows on the
/// same day have been merged, so no rate of return can exist.
final class InsufficientCashFlowsException extends XirrException {
  /// Creates the exception; [count] is the number of usable flows found.
  const InsufficientCashFlowsException(this.count)
      : super(
          'At least two non-zero cash flows on different days are required '
          '(found $count).',
        );

  /// How many non-zero flows remained after merging same-day flows.
  final int count;
}

/// Thrown when all cash flows have the same sign. An internal rate of return
/// needs at least one outflow (negative) and one inflow (positive).
final class NoSignChangeException extends XirrException {
  /// Creates the exception; [onlyPositive] tells which sign was present.
  const NoSignChangeException({required this.onlyPositive})
      : super(
          'Cash flows need at least one negative and one positive amount, '
          'but all are ${onlyPositive ? 'positive' : 'negative'}.',
        );

  /// `true` if every flow was an inflow, `false` if every flow was an outflow.
  final bool onlyPositive;
}

/// Thrown when no rate within the configured bounds satisfies the equation,
/// or the chosen solver did not converge within `maxIterations`.
final class NonConvergenceException extends XirrException {
  /// Creates the exception with diagnostics from the failed attempt.
  const NonConvergenceException(
    super.message, {
    required this.iterations,
    this.lastEstimate,
  });

  /// Solver iterations spent before giving up.
  final int iterations;

  /// The last finite rate estimate, if any. It is **not** a valid result.
  final double? lastEstimate;
}

/// Thrown when a cash flow amount is `NaN` or infinite.
final class InvalidCashFlowException extends XirrException {
  /// Creates the exception for the flow at [index] with the bad [amount].
  InvalidCashFlowException(this.index, this.amount)
      : super('Cash flow at index $index has a non-finite amount ($amount).');

  /// Position of the offending flow in the input (before sorting).
  final int index;

  /// The offending amount.
  final double amount;
}
