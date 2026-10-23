import 'dates.dart';

/// A single dated money movement.
///
/// The sign follows the investor's point of view: a **negative** [amount] is
/// money paid out (a purchase, a SIP instalment), a **positive** [amount] is
/// money received (a redemption, a dividend, the current market value).
///
/// Only the calendar day matters. The [date] is normalised to a UTC,
/// date-only value in the constructor, so a local `DateTime(2024, 3, 31, 23)`
/// and `DateTime.utc(2024, 3, 31)` are the same day and no time zone or
/// daylight-saving change can ever move a cash flow to another day.
///
/// ```dart
/// final invest = CashFlow(DateTime(2024, 1, 1), -10000);
/// final redeem = CashFlow(DateTime(2025, 1, 1), 11200);
/// ```
final class CashFlow {
  /// Creates a cash flow of [amount] on the calendar day of [date].
  ///
  /// The time-of-day and time zone of [date] are discarded.
  CashFlow(DateTime date, this.amount) : date = dateOnly(date);

  /// The calendar day of the flow, as a UTC midnight [DateTime].
  final DateTime date;

  /// The signed amount: negative = money out, positive = money in.
  final double amount;

  /// Returns a copy with the given fields replaced.
  CashFlow copyWith({DateTime? date, double? amount}) =>
      CashFlow(date ?? this.date, amount ?? this.amount);

  @override
  bool operator ==(Object other) =>
      other is CashFlow && other.date == date && other.amount == amount;

  @override
  int get hashCode => Object.hash(date, amount);

  @override
  String toString() => 'CashFlow(${isoDate(date)}, $amount)';
}
