import 'dart:math' as math;

import 'day_count.dart';

/// Compound annual growth rate between two values.
///
/// ```text
/// CAGR = (endValue / startValue) ^ (1 / years) - 1
/// ```
///
/// where `years` is the time from [startDate] to [endDate] measured by
/// [dayCount] (default `days / 365`). Use it for a single lump sum with no
/// interim deposits or withdrawals; with several cash flows use `xirr`.
///
/// Returns a fraction (`0.12` = 12 %). An [endValue] of `0` gives `-1`
/// (a total loss).
///
/// Throws [ArgumentError] if [startValue] is not a positive finite number,
/// [endValue] is negative or not finite, or [endDate] is not after
/// [startDate].
double cagr(
  double startValue,
  double endValue,
  DateTime startDate,
  DateTime endDate, {
  DayCount dayCount = DayCount.actual365,
}) {
  if (!startValue.isFinite || startValue <= 0) {
    throw ArgumentError.value(
        startValue, 'startValue', 'must be positive and finite');
  }
  if (!endValue.isFinite || endValue < 0) {
    throw ArgumentError.value(
        endValue, 'endValue', 'must be non-negative and finite');
  }
  final years = _years(startDate, endDate, dayCount);
  return math.pow(endValue / startValue, 1 / years).toDouble() - 1;
}

/// Simple (non-annualised) return of an investment.
///
/// ```text
/// absoluteReturn = (current - invested) / invested
/// ```
///
/// A result of `0.25` means a 25 % gain, `-0.1` a 10 % loss.
///
/// Throws [ArgumentError] if [invested] is zero or either value is not finite.
double absoluteReturn(double invested, double current) {
  if (!invested.isFinite || invested == 0) {
    throw ArgumentError.value(
        invested, 'invested', 'must be finite and non-zero');
  }
  if (!current.isFinite) {
    throw ArgumentError.value(current, 'current', 'must be finite');
  }
  return (current - invested) / invested;
}

/// Converts a [totalReturn] earned between [startDate] and [endDate] into an
/// annual rate by compounding.
///
/// ```text
/// annualized = (1 + totalReturn) ^ (1 / years) - 1
/// ```
///
/// For example 50 % over two years is `1.5^(1/2) - 1 = 22.47 %` per year.
/// [totalReturn] is a fraction (as returned by [absoluteReturn]).
///
/// Throws [ArgumentError] if [totalReturn] is below `-1` or not finite, or
/// [endDate] is not after [startDate].
double annualizedReturn(
  double totalReturn,
  DateTime startDate,
  DateTime endDate, {
  DayCount dayCount = DayCount.actual365,
}) {
  if (!totalReturn.isFinite || totalReturn < -1) {
    throw ArgumentError.value(
        totalReturn, 'totalReturn', 'must be finite and >= -1');
  }
  final years = _years(startDate, endDate, dayCount);
  return math.pow(1 + totalReturn, 1 / years).toDouble() - 1;
}

double _years(DateTime start, DateTime end, DayCount dayCount) {
  final years = dayCount.yearFraction(start, end);
  if (years <= 0) {
    throw ArgumentError.value(end, 'endDate', 'must be after the start date');
  }
  return years;
}
