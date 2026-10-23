import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:xirr/xirr.dart';

import 'reference.dart';

void main() {
  final flows = [
    CashFlow(DateTime(2008, 1, 1), -10000),
    CashFlow(DateTime(2008, 3, 1), 2750),
    CashFlow(DateTime(2008, 10, 30), 4250),
    CashFlow(DateTime(2009, 2, 15), 3250),
    CashFlow(DateTime(2009, 4, 1), 2750),
  ];

  test('matches the independent reference at several rates', () {
    for (final r in [-0.5, 0.0, 0.1, 0.373362535, 2.0]) {
      expect(xnpv(r, flows), closeTo(refNpv(r, flows), 1e-8), reason: '$r');
    }
  });

  test('is ~0 at the xirr', () {
    expect(xnpv(xirr(flows), flows).abs(), lessThan(1e-6));
  });

  test('zero rate is the plain sum', () {
    expect(xnpv(0, flows), closeTo(3000, 1e-9));
  });

  test('hand-checked single value', () {
    final f = [
      CashFlow(DateTime(2021, 1, 1), -100),
      CashFlow(DateTime(2023, 1, 1), 121)
    ];
    expect(xnpv(0.1, f).abs(), lessThan(1e-12));
    expect(xnpv(0.0, f), closeTo(21, 1e-12));
  });

  test('empty gives zero, order does not matter', () {
    expect(xnpv(0.1, const []), 0);
    expect(xnpv(0.1, flows.reversed), closeTo(xnpv(0.1, flows), 1e-9));
  });

  test('day count and asOf', () {
    final f = [
      CashFlow(DateTime(2021, 1, 1), -100),
      CashFlow(DateTime(2022, 1, 1), 110)
    ];
    expect(
      xnpv(0.1, f, dayCount: DayCount.actual360),
      closeTo(-100 + 110 / math.pow(1.1, 365 / 360), 1e-10),
    );
    // discounting to the end date: -100 compounded forward, +110 stays
    expect(
        xnpv(0.1, f, asOf: DateTime(2022, 1, 1)), closeTo(-110 + 110, 1e-10));
    expect(xnpv(0.1, f, asOf: DateTime(2021, 1, 1)), closeTo(0, 1e-10));
  });

  test('invalid rate', () {
    expect(() => xnpv(-1, flows), throwsArgumentError);
    expect(() => xnpv(-2, flows), throwsArgumentError);
    expect(() => xnpv(double.nan, flows), throwsArgumentError);
  });
}
