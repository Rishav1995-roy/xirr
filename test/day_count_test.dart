import 'package:test/test.dart';
import 'package:xirr/xirr.dart';

void main() {
  final a = DateTime(2020, 1, 1);
  final b = DateTime(2021, 1, 1); // 366 days later (2020 is a leap year)

  test('actual365 and actual360', () {
    expect(DayCount.actual365.yearFraction(a, b), closeTo(366 / 365, 1e-15));
    expect(DayCount.actual360.yearFraction(a, b), closeTo(366 / 360, 1e-15));
    expect(DayCount.actual365.yearFraction(a, a), 0);
  });

  test('actualActual: whole calendar years are exactly 1', () {
    expect(DayCount.actualActual.yearFraction(a, b), closeTo(1, 1e-15));
    expect(
      DayCount.actualActual
          .yearFraction(DateTime(2021, 1, 1), DateTime(2022, 1, 1)),
      closeTo(1, 1e-15),
    );
    expect(
      DayCount.actualActual
          .yearFraction(DateTime(2019, 1, 1), DateTime(2024, 1, 1)),
      closeTo(5, 1e-15),
    );
  });

  test('actualActual splits a span across years by year length', () {
    // 2019-07-01 -> 2020-07-01: 184 days in 2019 (/365) + 182 days in 2020 (/366)
    final v = DayCount.actualActual
        .yearFraction(DateTime(2019, 7, 1), DateTime(2020, 7, 1));
    expect(v, closeTo(184 / 365 + 182 / 366, 1e-15));
    // inside one year
    expect(
      DayCount.actualActual
          .yearFraction(DateTime(2020, 1, 1), DateTime(2020, 7, 1)),
      closeTo(182 / 366, 1e-15),
    );
    expect(
      DayCount.actualActual
          .yearFraction(DateTime(2021, 1, 1), DateTime(2021, 7, 1)),
      closeTo(181 / 365, 1e-15),
    );
  });

  test('reversed arguments give a negative value', () {
    expect(DayCount.actual365.yearFraction(b, a), closeTo(-366 / 365, 1e-15));
  });

  test('time zone and time of day are ignored', () {
    final x = DayCount.actual365.yearFraction(
        DateTime(2024, 3, 9, 23, 59), DateTime(2024, 3, 11, 0, 1));
    expect(x, closeTo(2 / 365, 1e-15));
    final u = DayCount.actual365
        .yearFraction(DateTime.utc(2024, 3, 9), DateTime.utc(2024, 3, 11));
    expect(x, u);
  });

  test('custom conventions', () {
    final thirty360 = DayCount.custom('30/360', (s, e) {
      final d1 = s.day > 30 ? 30 : s.day;
      final d2 = e.day > 30 && d1 == 30 ? 30 : e.day;
      return (360 * (e.year - s.year) + 30 * (e.month - s.month) + (d2 - d1)) /
          360;
    });
    expect(
        thirty360.yearFraction(DateTime(2021, 1, 1), DateTime(2022, 1, 1)), 1);
    expect(thirty360.name, '30/360');
    expect(thirty360.toString(), 'DayCount(30/360)');
  });

  test('invalid custom output is rejected', () {
    for (final bad in [double.nan, double.infinity, -1.0]) {
      final d = DayCount.custom('bad', (s, e) => bad);
      expect(() => d.yearFraction(a, b), throwsArgumentError);
    }
  });

  test('equality', () {
    expect(DayCount.actual365, DayCount.actual365);
    expect(DayCount.actual365 == DayCount.actual360, isFalse);
    expect(DayCount.actual365.hashCode, DayCount.actual365.hashCode);
    expect(DayCount.actual365 == Object(), isFalse);
  });
}
