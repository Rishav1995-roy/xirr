import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:xirr/xirr.dart';

void main() {
  group('cagr', () {
    test('doubling in 365 days is 100 %', () {
      expect(cagr(100, 200, DateTime(2021, 1, 1), DateTime(2022, 1, 1)),
          closeTo(1.0, 1e-12));
    });

    test('hand-checked: 1000 -> 1331 in 3 years (1095 days) is ~10 %', () {
      expect(
        cagr(1000, 1331, DateTime(2021, 1, 1), DateTime(2024, 1, 1)),
        closeTo(math.pow(1.331, 365 / 1095) - 1, 1e-12),
      );
    });

    test('agrees with xirr for two flows', () {
      final s = DateTime(2019, 4, 3);
      final e = DateTime(2024, 9, 20);
      expect(
        cagr(5000, 12345, s, e),
        closeTo(xirr([CashFlow(s, -5000), CashFlow(e, 12345)]), 1e-9),
      );
    });

    test('loss, total loss, day count', () {
      expect(cagr(100, 50, DateTime(2021, 1, 1), DateTime(2022, 1, 1)),
          closeTo(-0.5, 1e-12));
      expect(cagr(100, 0, DateTime(2021, 1, 1), DateTime(2022, 1, 1)), -1);
      expect(
        cagr(100, 110, DateTime(2020, 1, 1), DateTime(2021, 1, 1),
            dayCount: DayCount.actualActual),
        closeTo(0.1, 1e-12),
      );
    });

    test('validation', () {
      final s = DateTime(2021, 1, 1);
      final e = DateTime(2022, 1, 1);
      expect(() => cagr(0, 1, s, e), throwsArgumentError);
      expect(() => cagr(-1, 1, s, e), throwsArgumentError);
      expect(() => cagr(double.nan, 1, s, e), throwsArgumentError);
      expect(() => cagr(1, -1, s, e), throwsArgumentError);
      expect(() => cagr(1, double.infinity, s, e), throwsArgumentError);
      expect(() => cagr(1, 2, e, s), throwsArgumentError);
      expect(() => cagr(1, 2, s, s), throwsArgumentError);
    });
  });

  group('absoluteReturn', () {
    test('gain, loss, flat', () {
      expect(absoluteReturn(1000, 1250), closeTo(0.25, 1e-15));
      expect(absoluteReturn(1000, 900), closeTo(-0.1, 1e-15));
      expect(absoluteReturn(1000, 1000), 0);
      expect(absoluteReturn(1000, 0), -1);
    });

    test('validation', () {
      expect(() => absoluteReturn(0, 5), throwsArgumentError);
      expect(() => absoluteReturn(double.nan, 5), throwsArgumentError);
      expect(() => absoluteReturn(5, double.infinity), throwsArgumentError);
    });
  });

  group('annualizedReturn', () {
    test('50 % over two years', () {
      expect(
        annualizedReturn(0.5, DateTime(2021, 1, 1), DateTime(2023, 1, 1)),
        closeTo(math.pow(1.5, 365 / 730) - 1, 1e-12),
      );
    });

    test('equals cagr', () {
      final s = DateTime(2020, 2, 29);
      final e = DateTime(2024, 2, 29);
      expect(
        annualizedReturn(absoluteReturn(2000, 3100), s, e),
        closeTo(cagr(2000, 3100, s, e), 1e-12),
      );
    });

    test('total loss and validation', () {
      expect(
          annualizedReturn(-1, DateTime(2021, 1, 1), DateTime(2022, 1, 1)), -1);
      expect(
        annualizedReturn(0.1, DateTime(2020, 1, 1), DateTime(2021, 1, 1),
            dayCount: DayCount.actualActual),
        closeTo(0.1, 1e-12),
      );
      final s = DateTime(2021, 1, 1);
      expect(() => annualizedReturn(-1.5, s, DateTime(2022, 1, 1)),
          throwsArgumentError);
      expect(() => annualizedReturn(double.nan, s, DateTime(2022, 1, 1)),
          throwsArgumentError);
      expect(() => annualizedReturn(0.1, s, s), throwsArgumentError);
    });
  });
}
