import 'cash_flow.dart';
import 'dates.dart';

/// How often a SIP (systematic investment plan) instalment happens.
enum SipFrequency {
  /// Every calendar day.
  daily,

  /// Every business day (Monday to Friday by default; see the `isBusinessDay`
  /// argument of `sipSchedule`).
  businessDaily,

  /// Every 7 days.
  weekly,

  /// Every 14 days.
  fortnightly,

  /// Once a month on the start day; short months use their last day.
  monthly,

  /// Every 3 months.
  quarterly,

  /// Every 6 months.
  halfYearly,

  /// Once a year on the start day (Feb 29 becomes Feb 28 in common years).
  yearly,
}

/// What to do when a scheduled instalment date is not a business day.
enum BusinessDayAdjustment {
  /// Keep the date as it is.
  none,

  /// Move to the next business day (how most mutual funds process a SIP).
  following,

  /// Move to the previous business day.
  preceding,

  /// Move to the next business day, unless that is in the next month, in
  /// which case move to the previous business day.
  modifiedFollowing,
}

/// Signature of a predicate that says whether a (UTC, date-only) day is a
/// business day.
typedef BusinessDayPredicate = bool Function(DateTime day);

bool _isWeekday(DateTime d) =>
    d.weekday != DateTime.saturday && d.weekday != DateTime.sunday;

/// Generates the dated cash flows of a SIP.
///
/// The first instalment is on [start]. Give [count] (number of instalments),
/// [until] (last allowed date, inclusive) or both; the schedule ends at
/// whichever comes first. At least one is required.
///
/// Every date is computed from [start], not from the previous date, so month
/// ends never drift: a SIP starting on the 31st runs on Jan 31, Feb 28 (or
/// 29), Mar 31, Apr 30 and so on. A yearly SIP started on Feb 29 runs on Feb 29
/// in leap years and Feb 28 otherwise.
///
/// Amounts are negative (money leaving the investor) unless [asOutflow] is
/// `false`.
///
/// Business-day behaviour is customisable:
/// * [isBusinessDay] replaces the default Monday-Friday rule, e.g. to add
///   exchange holidays.
/// * [adjustment] moves instalments that land on a non-business day
///   (default [BusinessDayAdjustment.none]). It is ignored for
///   [SipFrequency.daily] and [SipFrequency.businessDaily].
///
/// Throws [ArgumentError] if [amount] is not positive and finite, [count] is
/// negative, neither [count] nor [until] is given, or [isBusinessDay] rejects
/// every day.
///
/// ```dart
/// final flows = sipSchedule(
///   amount: 5000,
///   start: DateTime(2024, 1, 31),
///   count: 12,
/// ); // Jan 31, Feb 29, Mar 31, Apr 30, ...
/// ```
List<CashFlow> sipSchedule({
  required double amount,
  required DateTime start,
  SipFrequency frequency = SipFrequency.monthly,
  int? count,
  DateTime? until,
  bool asOutflow = true,
  BusinessDayAdjustment adjustment = BusinessDayAdjustment.none,
  BusinessDayPredicate? isBusinessDay,
}) {
  if (!amount.isFinite || amount <= 0) {
    throw ArgumentError.value(amount, 'amount', 'must be positive and finite');
  }
  if (count == null && until == null) {
    throw ArgumentError('Provide count, until, or both.');
  }
  if (count != null && count < 0) {
    throw ArgumentError.value(count, 'count', 'must not be negative');
  }
  final first = dateOnly(start);
  final last = until == null ? null : dateOnly(until);
  final isBiz = isBusinessDay ?? _isWeekday;
  final signed = asOutflow ? -amount : amount;
  final out = <CashFlow>[];

  bool done(DateTime d) =>
      (count != null && out.length >= count) ||
      (last != null && d.isAfter(last));

  if (frequency == SipFrequency.businessDaily) {
    var day = first;
    var misses = 0;
    while (true) {
      if (count != null && out.length >= count) break;
      if (last != null && day.isAfter(last)) break;
      if (isBiz(day)) {
        out.add(CashFlow(day, signed));
        misses = 0;
      } else if (++misses > 3660) {
        throw ArgumentError.value(
            isBusinessDay, 'isBusinessDay', 'rejects every day');
      }
      day = addDays(day, 1);
    }
    return out;
  }

  for (var k = 0;; k++) {
    var day = _nominal(first, frequency, k);
    if (frequency != SipFrequency.daily) {
      day = _adjust(day, adjustment, isBiz);
    }
    if (done(day)) break;
    out.add(CashFlow(day, signed));
  }
  return out;
}

DateTime _nominal(DateTime first, SipFrequency f, int k) {
  switch (f) {
    case SipFrequency.daily:
    case SipFrequency.businessDaily:
      return addDays(first, k);
    case SipFrequency.weekly:
      return addDays(first, 7 * k);
    case SipFrequency.fortnightly:
      return addDays(first, 14 * k);
    case SipFrequency.monthly:
      return addMonths(first, k);
    case SipFrequency.quarterly:
      return addMonths(first, 3 * k);
    case SipFrequency.halfYearly:
      return addMonths(first, 6 * k);
    case SipFrequency.yearly:
      return addMonths(first, 12 * k);
  }
}

DateTime _adjust(
  DateTime day,
  BusinessDayAdjustment adj,
  BusinessDayPredicate isBiz,
) {
  if (adj == BusinessDayAdjustment.none || isBiz(day)) return day;
  DateTime walk(int step) {
    var d = day;
    for (var i = 0; i < 3660; i++) {
      d = addDays(d, step);
      if (isBiz(d)) return d;
    }
    throw ArgumentError.value(isBiz, 'isBusinessDay', 'rejects every day');
  }

  switch (adj) {
    case BusinessDayAdjustment.none:
      return day;
    case BusinessDayAdjustment.following:
      return walk(1);
    case BusinessDayAdjustment.preceding:
      return walk(-1);
    case BusinessDayAdjustment.modifiedFollowing:
      final next = walk(1);
      return next.month == day.month ? next : walk(-1);
  }
}
