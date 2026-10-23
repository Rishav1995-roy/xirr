import 'package:test/test.dart';
import 'package:xirr/xirr.dart';

String d(CashFlow f) =>
    '${f.date.year}-${f.date.month.toString().padLeft(2, '0')}-${f.date.day.toString().padLeft(2, '0')}';

List<String> dates(List<CashFlow> flows) => flows.map(d).toList();

void main() {
  group('monthly', () {
    test('31st clamps to month end without drifting (leap year)', () {
      final s =
          sipSchedule(amount: 5000, start: DateTime(2024, 1, 31), count: 6);
      expect(dates(s), [
        '2024-01-31',
        '2024-02-29',
        '2024-03-31',
        '2024-04-30',
        '2024-05-31',
        '2024-06-30',
      ]);
    });

    test('31st in a common year', () {
      final s = sipSchedule(amount: 1, start: DateTime(2023, 1, 31), count: 3);
      expect(dates(s), ['2023-01-31', '2023-02-28', '2023-03-31']);
    });

    test('30th and 29th', () {
      expect(
        dates(sipSchedule(amount: 1, start: DateTime(2023, 1, 30), count: 3)),
        ['2023-01-30', '2023-02-28', '2023-03-30'],
      );
      expect(
        dates(sipSchedule(amount: 1, start: DateTime(2023, 1, 29), count: 3)),
        ['2023-01-29', '2023-02-28', '2023-03-29'],
      );
      expect(
        dates(sipSchedule(amount: 1, start: DateTime(2024, 1, 29), count: 3)),
        ['2024-01-29', '2024-02-29', '2024-03-29'],
      );
    });

    test('year rollover', () {
      final s = sipSchedule(amount: 1, start: DateTime(2023, 11, 15), count: 4);
      expect(
          dates(s), ['2023-11-15', '2023-12-15', '2024-01-15', '2024-02-15']);
    });

    test('until is inclusive', () {
      final s = sipSchedule(
          amount: 1,
          start: DateTime(2024, 1, 10),
          until: DateTime(2024, 4, 10));
      expect(
          dates(s), ['2024-01-10', '2024-02-10', '2024-03-10', '2024-04-10']);
      final t = sipSchedule(
          amount: 1, start: DateTime(2024, 1, 10), until: DateTime(2024, 4, 9));
      expect(t.length, 3);
    });

    test('count and until: whichever comes first', () {
      expect(
        sipSchedule(
                amount: 1,
                start: DateTime(2024, 1, 10),
                count: 2,
                until: DateTime(2025, 1, 1))
            .length,
        2,
      );
      expect(
        sipSchedule(
                amount: 1,
                start: DateTime(2024, 1, 10),
                count: 20,
                until: DateTime(2024, 3, 11))
            .length,
        3,
      );
    });

    test('empty cases', () {
      expect(sipSchedule(amount: 1, start: DateTime(2024, 1, 10), count: 0),
          isEmpty);
      expect(
        sipSchedule(
            amount: 1,
            start: DateTime(2024, 1, 10),
            until: DateTime(2024, 1, 9)),
        isEmpty,
      );
    });

    test('amounts are negative by default, positive on request', () {
      final out =
          sipSchedule(amount: 250.5, start: DateTime(2024, 1, 1), count: 2);
      expect(out.map((f) => f.amount), [-250.5, -250.5]);
      final inn = sipSchedule(
          amount: 250.5,
          start: DateTime(2024, 1, 1),
          count: 2,
          asOutflow: false);
      expect(inn.map((f) => f.amount), [250.5, 250.5]);
    });

    test('time of day and zone of start are ignored', () {
      final s = sipSchedule(
          amount: 1, start: DateTime(2024, 1, 31, 23, 59), count: 2);
      expect(dates(s), ['2024-01-31', '2024-02-29']);
      expect(s.first.date.isUtc, isTrue);
    });

    test('long schedule has no duplicates and is increasing', () {
      final s =
          sipSchedule(amount: 1, start: DateTime(2000, 1, 31), count: 600);
      for (var i = 1; i < s.length; i++) {
        expect(s[i].date.isAfter(s[i - 1].date), isTrue);
      }
      expect(d(s.last), '2049-12-31');
    });
  });

  group('other frequencies', () {
    test('yearly from Feb 29', () {
      final s = sipSchedule(
        amount: 1,
        start: DateTime(2024, 2, 29),
        frequency: SipFrequency.yearly,
        count: 5,
      );
      expect(dates(s), [
        '2024-02-29',
        '2025-02-28',
        '2026-02-28',
        '2027-02-28',
        '2028-02-29'
      ]);
    });

    test('quarterly from Nov 30', () {
      final s = sipSchedule(
        amount: 1,
        start: DateTime(2024, 11, 30),
        frequency: SipFrequency.quarterly,
        count: 5,
      );
      expect(dates(s), [
        '2024-11-30',
        '2025-02-28',
        '2025-05-30',
        '2025-08-30',
        '2025-11-30'
      ]);
    });

    test('half-yearly from Aug 31', () {
      final s = sipSchedule(
        amount: 1,
        start: DateTime(2024, 8, 31),
        frequency: SipFrequency.halfYearly,
        count: 3,
      );
      expect(dates(s), ['2024-08-31', '2025-02-28', '2025-08-31']);
    });

    test('weekly and fortnightly', () {
      expect(
        dates(sipSchedule(
          amount: 1,
          start: DateTime(2024, 2, 22),
          frequency: SipFrequency.weekly,
          count: 3,
        )),
        ['2024-02-22', '2024-02-29', '2024-03-07'],
      );
      expect(
        dates(sipSchedule(
          amount: 1,
          start: DateTime(2024, 12, 25),
          frequency: SipFrequency.fortnightly,
          count: 3,
        )),
        ['2024-12-25', '2025-01-08', '2025-01-22'],
      );
    });

    test('daily crosses Feb 29', () {
      final s = sipSchedule(
        amount: 1,
        start: DateTime(2024, 2, 28),
        frequency: SipFrequency.daily,
        count: 3,
      );
      expect(dates(s), ['2024-02-28', '2024-02-29', '2024-03-01']);
    });

    test('daily ignores the adjustment', () {
      final s = sipSchedule(
        amount: 1,
        start: DateTime(2024, 6, 1), // Saturday
        frequency: SipFrequency.daily,
        count: 2,
        adjustment: BusinessDayAdjustment.following,
      );
      expect(dates(s), ['2024-06-01', '2024-06-02']);
    });
  });

  group('business days', () {
    test('businessDaily skips weekends', () {
      final s = sipSchedule(
        amount: 1,
        start: DateTime(2024, 3, 1), // Friday
        frequency: SipFrequency.businessDaily,
        count: 4,
      );
      expect(
          dates(s), ['2024-03-01', '2024-03-04', '2024-03-05', '2024-03-06']);
    });

    test('businessDaily starting on a weekend, with until', () {
      final s = sipSchedule(
        amount: 1,
        start: DateTime(2024, 3, 2), // Saturday
        frequency: SipFrequency.businessDaily,
        until: DateTime(2024, 3, 6),
      );
      expect(dates(s), ['2024-03-04', '2024-03-05', '2024-03-06']);
    });

    test('custom holiday calendar', () {
      final holidays = {DateTime.utc(2024, 3, 4)};
      final s = sipSchedule(
        amount: 1,
        start: DateTime(2024, 3, 1),
        frequency: SipFrequency.businessDaily,
        count: 4,
        isBusinessDay: (day) => day.weekday < 6 && !holidays.contains(day),
      );
      expect(
          dates(s), ['2024-03-01', '2024-03-05', '2024-03-06', '2024-03-07']);
    });

    test('adjustments', () {
      DateTime sat() => DateTime(2024, 6, 1); // Saturday
      expect(
        dates(sipSchedule(
          amount: 1,
          start: sat(),
          count: 3,
          adjustment: BusinessDayAdjustment.following,
        )),
        ['2024-06-03', '2024-07-01', '2024-08-01'],
      );
      expect(
        dates(sipSchedule(
          amount: 1,
          start: sat(),
          count: 2,
          adjustment: BusinessDayAdjustment.preceding,
        )),
        ['2024-05-31', '2024-07-01'],
      );
      expect(
        dates(sipSchedule(
          amount: 1,
          start: sat(),
          count: 1,
          adjustment: BusinessDayAdjustment.none,
        )),
        ['2024-06-01'],
      );
    });

    test('modified following stays in the month', () {
      // Aug 31 2024 is a Saturday: following would be Sep 2
      final s = sipSchedule(
        amount: 1,
        start: DateTime(2024, 8, 31),
        count: 2,
        adjustment: BusinessDayAdjustment.modifiedFollowing,
      );
      expect(d(s.first), '2024-08-30');
      // Jun 1 2024 (Saturday): following (Jun 3) stays in the month
      final t = sipSchedule(
        amount: 1,
        start: DateTime(2024, 6, 1),
        count: 1,
        adjustment: BusinessDayAdjustment.modifiedFollowing,
      );
      expect(d(t.first), '2024-06-03');
    });

    test('a calendar with no business days is rejected', () {
      expect(
        () => sipSchedule(
          amount: 1,
          start: DateTime(2024, 3, 1),
          frequency: SipFrequency.businessDaily,
          count: 1,
          isBusinessDay: (_) => false,
        ),
        throwsArgumentError,
      );
      expect(
        () => sipSchedule(
          amount: 1,
          start: DateTime(2024, 3, 1),
          count: 1,
          adjustment: BusinessDayAdjustment.following,
          isBusinessDay: (_) => false,
        ),
        throwsArgumentError,
      );
    });
  });

  group('validation', () {
    test('amount, count and bounds', () {
      final s = DateTime(2024, 1, 1);
      expect(() => sipSchedule(amount: 0, start: s, count: 1),
          throwsArgumentError);
      expect(() => sipSchedule(amount: -5, start: s, count: 1),
          throwsArgumentError);
      expect(() => sipSchedule(amount: double.nan, start: s, count: 1),
          throwsArgumentError);
      expect(() => sipSchedule(amount: 1, start: s), throwsArgumentError);
      expect(() => sipSchedule(amount: 1, start: s, count: -1),
          throwsArgumentError);
    });
  });

  test('a SIP feeds straight into xirr', () {
    final flows = [
      ...sipSchedule(amount: 10000, start: DateTime(2023, 1, 5), count: 12),
      CashFlow(DateTime(2024, 1, 5), 130000),
    ];
    final r = xirr(flows);
    expect(r, greaterThan(0.1));
    expect(r, lessThan(0.3));
    expect(xnpv(r, flows).abs(), lessThan(1e-6));
  });
}
