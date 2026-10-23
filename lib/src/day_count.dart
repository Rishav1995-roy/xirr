import 'dates.dart';

/// Signature of a function that converts two calendar days into a length of
/// time in years.
///
/// Called with `start` <= `end`, both UTC date-only values. It must return a
/// finite, non-negative number and `0` when both days are equal.
typedef YearFractionFn = double Function(DateTime start, DateTime end);

/// A day-count convention: how the time between two dates is measured in
/// years, which decides the exponent `t` in `(1 + rate)^t`.
///
/// Built-in conventions are [actual365] (the Excel default), [actual360] and
/// [actualActual]. To use your own rule, create one with [DayCount.custom]:
///
/// ```dart
/// // 30/360 (US-style, simplified)
/// final thirty360 = DayCount.custom('30/360', (a, b) {
///   final d1 = a.day > 30 ? 30 : a.day;
///   final d2 = b.day > 30 && d1 == 30 ? 30 : b.day;
///   return (360 * (b.year - a.year) + 30 * (b.month - a.month) + (d2 - d1)) /
///       360;
/// });
/// ```
final class DayCount {
  /// Creates a convention from a [name] and a [YearFractionFn].
  const DayCount.custom(this.name, YearFractionFn yearFractionFn)
      : _fn = yearFractionFn;

  /// Actual days divided by 365. This is what Excel's `XIRR` and `XNPV` use,
  /// and the default of this package.
  static const DayCount actual365 = DayCount.custom('Actual/365', _actual365);

  /// Actual days divided by 360 (money-market convention).
  static const DayCount actual360 = DayCount.custom('Actual/360', _actual360);

  /// Actual/Actual (ISDA): days falling in each calendar year are divided by
  /// that year's length (365 or 366), so one full calendar year is exactly
  /// `1.0` even across a leap year.
  static const DayCount actualActual =
      DayCount.custom('Actual/Actual', _actualActual);

  /// Short display name, such as `Actual/365`.
  final String name;

  final YearFractionFn _fn;

  /// Years between [start] and [end]. Negative when [end] is before [start].
  ///
  /// Arguments are reduced to calendar days first, so time zones and the
  /// time-of-day are ignored.
  double yearFraction(DateTime start, DateTime end) {
    final a = dateOnly(start);
    final b = dateOnly(end);
    if (b.isBefore(a)) return -_checked(b, a);
    return _checked(a, b);
  }

  double _checked(DateTime a, DateTime b) {
    final v = _fn(a, b);
    if (!v.isFinite || v < 0) {
      throw ArgumentError.value(
        v,
        'yearFraction',
        'DayCount "$name" returned a non-finite or negative value for '
            '${isoDate(a)} to ${isoDate(b)}.',
      );
    }
    return v;
  }

  @override
  bool operator ==(Object other) =>
      other is DayCount && other.name == name && other._fn == _fn;

  @override
  int get hashCode => Object.hash(name, _fn);

  @override
  String toString() => 'DayCount($name)';
}

double _actual365(DateTime a, DateTime b) => daysBetween(a, b) / 365.0;

double _actual360(DateTime a, DateTime b) => daysBetween(a, b) / 360.0;

double _actualActual(DateTime a, DateTime b) {
  if (a.year == b.year) {
    return daysBetween(a, b) / (isLeapYear(a.year) ? 366.0 : 365.0);
  }
  final startOfNextYear = DateTime.utc(a.year + 1);
  final startOfEndYear = DateTime.utc(b.year);
  final first =
      daysBetween(a, startOfNextYear) / (isLeapYear(a.year) ? 366.0 : 365.0);
  final last =
      daysBetween(startOfEndYear, b) / (isLeapYear(b.year) ? 366.0 : 365.0);
  return first + (b.year - a.year - 1) + last;
}
