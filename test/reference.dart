// Independent reference implementation used only by the tests.
//
// It deliberately shares no code with lib/: plain `pow`, plain DateTime
// differences and a brute-force bisection with 400 halvings.
import 'dart:math' as math;

import 'package:xirr/xirr.dart';

/// Reference NPV with Actual/365 and the first flow's date as the origin.
double refNpv(double rate, List<CashFlow> flows, {double yearDays = 365}) {
  final origin =
      flows.map((f) => f.date).reduce((a, b) => a.isBefore(b) ? a : b);
  var sum = 0.0;
  for (final f in flows) {
    final days = f.date.difference(origin).inHours / 24.0;
    sum += f.amount / math.pow(1 + rate, days / yearDays);
  }
  return sum;
}

/// Reference XIRR by bisection on [lo, hi]; assumes one sign change of NPV.
double refXirr(
  List<CashFlow> flows, {
  double lo = -0.999999,
  double hi = 1e7,
  double yearDays = 365,
}) {
  var a = lo;
  var b = hi;
  final aNeg = refNpv(a, flows, yearDays: yearDays) < 0;
  for (var i = 0; i < 400; i++) {
    final m = (a + b) / 2;
    final neg = refNpv(m, flows, yearDays: yearDays) < 0;
    if (neg == aNeg) {
      a = m;
    } else {
      b = m;
    }
  }
  return (a + b) / 2;
}

/// Monthly SIP of [amount] for [months] months starting [start] (day <= 28),
/// plus a final redemption of [finalValue] on [end].
List<CashFlow> syntheticSip(
  double amount,
  DateTime start,
  int months,
  double finalValue,
  DateTime end,
) =>
    [
      for (var i = 0; i < months; i++)
        CashFlow(DateTime.utc(start.year, start.month + i, start.day), -amount),
      CashFlow(end, finalValue),
    ];
