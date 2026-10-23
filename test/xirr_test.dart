import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:xirr/xirr.dart';

import 'reference.dart';

CashFlow cf(int y, int m, int d, double a) => CashFlow(DateTime(y, m, d), a);

List<CashFlow> microsoftExample() => [
      cf(2008, 1, 1, -10000),
      cf(2008, 3, 1, 2750),
      cf(2008, 10, 30, 4250),
      cf(2009, 2, 15, 3250),
      cf(2009, 4, 1, 2750),
    ];

void main() {
  group('Excel parity', () {
    test('Microsoft documented XIRR example = 0.373362535', () {
      expect(xirr(microsoftExample()), closeTo(0.373362535, 5e-9));
    });

    test('Microsoft example matches independent bisection to 1e-12', () {
      expect(xirr(microsoftExample()),
          closeTo(refXirr(microsoftExample()), 1e-12));
    });

    test('one year over a leap year: 1.1^(365/366) - 1', () {
      final flows = [cf(2020, 1, 1, -1000), cf(2021, 1, 1, 1100)];
      expect(xirr(flows), closeTo(math.pow(1.1, 365 / 366) - 1, 1e-12));
    });

    test('exactly 365 days doubling is 100 %', () {
      final flows = [cf(2021, 1, 1, -100), cf(2022, 1, 1, 200)];
      expect(xirr(flows), closeTo(1.0, 1e-10));
    });

    test('730 days, 100 -> 121 is exactly 10 %', () {
      final flows = [cf(2021, 1, 1, -100), cf(2023, 1, 1, 121)];
      expect(xirr(flows), closeTo(0.1, 1e-10));
    });

    test('three flows hand-solved: -100, +60 at 1y, +60 at 2y', () {
      // -100 + 60/(1+r) + 60/(1+r)^2 = 0  ->  1 + r = (60 + sqrt(60^2 + 4*100*60)) / 200 ... solve y = 1/(1+r)
      // 60y^2 + 60y - 100 = 0 -> y = (-60 + sqrt(3600 + 24000)) / 120
      final y = (-60 + math.sqrt(3600 + 24000)) / 120;
      final flows = [
        cf(2021, 1, 1, -100),
        cf(2022, 1, 1, 60),
        cf(2023, 1, 1, 60)
      ];
      expect(xirr(flows), closeTo(1 / y - 1, 1e-10));
    });

    test('flow order and input type do not matter', () {
      final shuffled = microsoftExample().reversed.toList()..swap(0, 2);
      expect(xirr(shuffled), closeTo(xirr(microsoftExample()), 1e-14));
      expect(xirr(microsoftExample().toSet()), closeTo(0.373362535, 5e-9));
    });

    test('synthetic SIP matches independent bisection', () {
      final flows = syntheticSip(
        5000,
        DateTime.utc(2019, 1, 5),
        60,
        420000,
        DateTime.utc(2024, 1, 5),
      );
      expect(xirr(flows), closeTo(refXirr(flows), 1e-10));
    });

    test('many random synthetic portfolios match the reference', () {
      final rnd = math.Random(7);
      for (var n = 0; n < 40; n++) {
        final flows = <CashFlow>[];
        var invested = 0.0;
        for (var i = 0; i < 6 + rnd.nextInt(20); i++) {
          final amt = 1000 + rnd.nextInt(9000).toDouble();
          invested += amt;
          flows.add(
            CashFlow(DateTime.utc(2018, 1, 1 + rnd.nextInt(1000)), -amt),
          );
        }
        final mult = 0.5 + rnd.nextDouble() * 2;
        flows.add(CashFlow(
            DateTime.utc(2022, 1, 1 + rnd.nextInt(400)), invested * mult));
        // The terminal inflow is after every outflow? Not guaranteed; only
        // assert when it is, so there is exactly one sign change.
        final lastOut = flows
            .take(flows.length - 1)
            .map((f) => f.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        if (!flows.last.date.isAfter(lastOut)) continue;
        expect(
          xirr(flows),
          closeTo(refXirr(flows), 1e-9),
          reason: 'case $n',
        );
      }
    });
  });

  group('edge shapes', () {
    test('negative return', () {
      final flows = [cf(2021, 1, 1, -100), cf(2022, 1, 1, 50)];
      expect(xirr(flows), closeTo(-0.5, 1e-10));
    });

    test('severe loss -99 %', () {
      final flows = [cf(2021, 1, 1, -100), cf(2022, 1, 1, 1)];
      expect(xirr(flows), closeTo(-0.99, 1e-10));
    });

    test('1000 % return', () {
      final flows = [cf(2021, 1, 1, -100), cf(2022, 1, 1, 1100)];
      expect(xirr(flows), closeTo(10.0, 1e-9));
    });

    test('1,000,000 % return', () {
      final flows = [cf(2021, 1, 1, -1), cf(2022, 1, 1, 10001)];
      expect(xirr(flows) / 10000, closeTo(1.0, 1e-9));
    });

    test('very short, very high annualised return', () {
      final flows = [cf(2021, 1, 1, -100), cf(2021, 1, 31, 110)];
      expect(xirr(flows), closeTo(math.pow(1.1, 365 / 30) - 1, 1e-6));
    });

    test('flows that start with an inflow (a loan)', () {
      final flows = [cf(2021, 1, 1, 1000), cf(2022, 1, 1, -1100)];
      expect(xirr(flows), closeTo(0.1, 1e-10));
    });

    test('200 year horizon', () {
      final flows = [cf(1900, 1, 1, -100), cf(2100, 1, 1, 100000)];
      final years =
          DateTime.utc(2100).difference(DateTime.utc(1900)).inDays / 365;
      expect(xirr(flows), closeTo(math.pow(1000, 1 / years) - 1, 1e-10));
    });

    test('long horizon with a near -100 % result', () {
      final flows = [cf(1950, 1, 1, -100), cf(2050, 1, 1, 1e-20)];
      final years =
          DateTime.utc(2050).difference(DateTime.utc(1950)).inDays / 365;
      final expected = math.pow(1e-22, 1 / years) - 1;
      expect(xirr(flows), closeTo(expected, 1e-9));
    });

    test('two roots: the one nearest the guess is returned', () {
      // -100 + 230/(1+r) - 132/(1+r)^2 = 0  ->  r = 10 % and r = 20 %
      final flows = [
        cf(2021, 1, 1, -100),
        cf(2022, 1, 1, 230),
        cf(2023, 1, 1, -132)
      ];
      expect(xirr(flows, options: const XirrOptions(guess: 0.0)),
          closeTo(0.1, 1e-9));
      expect(xirr(flows, options: const XirrOptions(guess: 0.3)),
          closeTo(0.2, 1e-9));
      for (final m in SolverMethod.values) {
        final r = xirr(flows, options: XirrOptions(guess: 0.05, method: m));
        expect(xnpv(r, flows).abs(), lessThan(1e-6), reason: m.name);
      }
      expect(
        xirr(flows,
            options:
                const XirrOptions(guess: 0.05, method: SolverMethod.bisection)),
        closeTo(0.1, 1e-9),
      );
    });

    test('same-day flows are merged', () {
      final merged = [cf(2021, 1, 1, -100), cf(2022, 1, 1, 130)];
      final split = [
        cf(2021, 1, 1, -60),
        cf(2022, 1, 1, 100),
        cf(2021, 1, 1, -40),
        cf(2022, 1, 1, 30),
      ];
      expect(xirr(split), closeTo(xirr(merged), 1e-14));
      expect(xirrDetailed(split).cashFlowCount, 2);
    });

    test('zero amounts are ignored', () {
      final flows = [
        cf(2020, 6, 1, 0),
        cf(2021, 1, 1, -100),
        cf(2022, 1, 1, 130)
      ];
      expect(xirr(flows), closeTo(0.3, 1e-10));
      expect(xirrDetailed(flows).cashFlowCount, 2);
    });

    test('flows that cancel on one day leave too few flows', () {
      final flows = [
        cf(2021, 1, 1, -100),
        cf(2021, 1, 1, 100),
        cf(2022, 1, 1, 5)
      ];
      expect(
        () => xirr(flows),
        throwsA(isA<InsufficientCashFlowsException>()
            .having((e) => e.count, 'count', 1)),
      );
    });
  });

  group('time zones', () {
    test('local and UTC DateTimes give identical results', () {
      final local = [
        DateTime(2023, 3, 12), // around a US DST change
        DateTime(2023, 3, 26),
        DateTime(2023, 10, 29), // around an EU DST change
        DateTime(2024, 3, 31),
      ];
      final amounts = [-1000.0, -500.0, 700.0, 1100.0];
      final a = [for (var i = 0; i < 4; i++) CashFlow(local[i], amounts[i])];
      final b = [
        for (var i = 0; i < 4; i++)
          CashFlow(DateTime.utc(local[i].year, local[i].month, local[i].day),
              amounts[i]),
      ];
      final c = [
        for (var i = 0; i < 4; i++)
          CashFlow(
            DateTime(local[i].year, local[i].month, local[i].day, 23, 59, 59),
            amounts[i],
          ),
      ];
      expect(xirr(a), xirr(b));
      expect(xirr(c), xirr(b));
    });

    test('time of day is discarded', () {
      final f = CashFlow(DateTime(2024, 3, 31, 23, 30), 5);
      expect(f.date, DateTime.utc(2024, 3, 31));
      expect(f.date.isUtc, isTrue);
    });
  });

  group('options', () {
    test('every method agrees on a well-behaved series', () {
      final expected = xirr(microsoftExample());
      for (final m in SolverMethod.values) {
        expect(
          xirr(microsoftExample(), options: XirrOptions(method: m)),
          closeTo(expected, 1e-9),
          reason: m.name,
        );
      }
    });

    test('every method handles a 1000 % return and a -90 % return', () {
      for (final m in SolverMethod.values) {
        final o = XirrOptions(method: m);
        expect(xirr([cf(2021, 1, 1, -100), cf(2022, 1, 1, 1100)], options: o),
            closeTo(10, 1e-8),
            reason: m.name);
        expect(xirr([cf(2021, 1, 1, -100), cf(2022, 1, 1, 10)], options: o),
            closeTo(-0.9, 1e-8),
            reason: m.name);
      }
    });

    test('plain newton can fail where auto succeeds', () {
      final flows = [cf(2021, 1, 1, -100), cf(2021, 4, 1, 300)]; // 90 days
      final expected = math.pow(3, 365 / 90) - 1;
      const o = XirrOptions(method: SolverMethod.newton, maxIterations: 2);
      expect(() => xirr(flows, options: o),
          throwsA(isA<NonConvergenceException>()));
      expect(tryXirr(flows, options: o), isNull);
      expect(xirr(flows), closeTo(expected, 1e-7));
    });

    test('guess far from the answer still converges', () {
      for (final g in [-0.9, 0.0, 5.0, 1000.0]) {
        expect(
          xirr(microsoftExample(), options: XirrOptions(guess: g)),
          closeTo(0.373362535, 1e-8),
          reason: 'guess $g',
        );
      }
    });

    test('tolerance controls precision', () {
      final loose = xirr(
        microsoftExample(),
        options:
            const XirrOptions(method: SolverMethod.bisection, tolerance: 1e-3),
      );
      expect((loose - 0.37336253352).abs(), lessThan(1e-3));
      final tight = xirr(
        microsoftExample(),
        options:
            const XirrOptions(method: SolverMethod.brent, tolerance: 1e-14),
      );
      expect(tight, closeTo(0.3733625335188314, 1e-12));
    });

    test('day count conventions', () {
      final flows = [cf(2021, 1, 1, -100), cf(2022, 1, 1, 110)]; // 365 days
      expect(xirr(flows), closeTo(0.1, 1e-10));
      expect(
        xirr(flows, options: const XirrOptions(dayCount: DayCount.actual360)),
        closeTo(math.pow(1.1, 360 / 365) - 1, 1e-10),
      );
      final leap = [cf(2020, 1, 1, -100), cf(2021, 1, 1, 110)]; // 366 days
      expect(
        xirr(leap, options: const XirrOptions(dayCount: DayCount.actualActual)),
        closeTo(0.1, 1e-10),
      );
      expect(xirr(leap), closeTo(math.pow(1.1, 365 / 366) - 1, 1e-10));
    });

    test('custom day count', () {
      final doubled =
          DayCount.custom('double', (a, b) => 2 * b.difference(a).inDays / 365);
      final flows = [cf(2021, 1, 1, -100), cf(2022, 1, 1, 121)];
      expect(xirr(flows, options: XirrOptions(dayCount: doubled)),
          closeTo(0.1, 1e-10));
    });

    test('custom day count returning NaN is rejected', () {
      final bad = DayCount.custom('bad', (a, b) => double.nan);
      expect(
        () => xirr(microsoftExample(), options: XirrOptions(dayCount: bad)),
        throwsArgumentError,
      );
    });

    test('bounds', () {
      final flows = [cf(2021, 1, 1, -100), cf(2022, 1, 1, 1100)];
      expect(
        () => xirr(flows, options: const XirrOptions(maxRate: 5)),
        throwsA(isA<NonConvergenceException>()),
      );
      expect(
        xirr(flows,
            options: const XirrOptions(minRate: -0.5, maxRate: 20, guess: 1)),
        closeTo(10, 1e-8),
      );
    });

    test('copyWith and toString', () {
      const o = XirrOptions();
      final c = o.copyWith(
        guess: 0.2,
        tolerance: 1e-6,
        maxIterations: 7,
        dayCount: DayCount.actual360,
        method: SolverMethod.brent,
        minRate: -0.5,
        maxRate: 9,
      );
      expect(c.guess, 0.2);
      expect(c.tolerance, 1e-6);
      expect(c.maxIterations, 7);
      expect(c.dayCount, DayCount.actual360);
      expect(c.method, SolverMethod.brent);
      expect(c.minRate, -0.5);
      expect(c.maxRate, 9);
      expect(o.copyWith().toString(), o.toString());
      expect(o.toString(), contains('Actual/365'));
    });

    test('invalid options throw ArgumentError', () {
      final f = microsoftExample();
      for (final bad in [
        const XirrOptions(tolerance: 0),
        const XirrOptions(tolerance: double.nan),
        const XirrOptions(maxIterations: 0),
        const XirrOptions(minRate: -1),
        const XirrOptions(minRate: double.nan),
        const XirrOptions(maxRate: 0.01, minRate: 0.5, guess: 0.5),
        const XirrOptions(guess: -0.9999999999),
        const XirrOptions(guess: 1e12),
        const XirrOptions(guess: double.nan),
      ]) {
        expect(() => xirr(f, options: bad), throwsArgumentError,
            reason: '$bad');
        expect(() => tryXirr(f, options: bad), throwsArgumentError);
      }
    });
  });

  group('exceptions', () {
    test('empty and single flow: InsufficientCashFlowsException', () {
      expect(() => xirr([]), throwsA(isA<InsufficientCashFlowsException>()));
      final one = [cf(2021, 1, 1, -100)];
      expect(
        () => xirr(one),
        throwsA(isA<InsufficientCashFlowsException>()
            .having((e) => e.count, 'count', 1)),
      );
      expect(tryXirr(one), isNull);
    });

    test('all negative / all positive: NoSignChangeException', () {
      expect(
        () => xirr([cf(2021, 1, 1, -1), cf(2022, 1, 1, -2)]),
        throwsA(isA<NoSignChangeException>()
            .having((e) => e.onlyPositive, 'onlyPositive', false)),
      );
      expect(
        () => xirr([cf(2021, 1, 1, 1), cf(2022, 1, 1, 2)]),
        throwsA(isA<NoSignChangeException>()
            .having((e) => e.onlyPositive, 'onlyPositive', true)),
      );
    });

    test('NaN and infinity: InvalidCashFlowException with index', () {
      for (final bad in [
        double.nan,
        double.infinity,
        double.negativeInfinity
      ]) {
        final flows = [
          cf(2021, 1, 1, -100),
          cf(2022, 1, 1, bad),
          cf(2023, 1, 1, 5)
        ];
        expect(
          () => xirr(flows),
          throwsA(isA<InvalidCashFlowException>()
              .having((e) => e.index, 'index', 1)),
        );
        expect(tryXirr(flows), isNull);
        expect(() => xirrDetailed(flows),
            throwsA(isA<InvalidCashFlowException>()));
        expect(
            () => xnpv(0.1, flows), throwsA(isA<InvalidCashFlowException>()));
      }
    });

    test('no root inside the bounds: NonConvergenceException', () {
      final flows = [
        cf(2021, 1, 1, -100),
        cf(2022, 1, 1, 1e-12)
      ]; // r ~ -1 + 1e-14
      for (final m in SolverMethod.values) {
        expect(
          () => xirr(flows, options: XirrOptions(method: m)),
          throwsA(isA<NonConvergenceException>()),
          reason: m.name,
        );
      }
    });

    test('a series with no real root: NonConvergenceException', () {
      // -3 + 2y - y^2 has no real root
      final flows = [cf(2021, 1, 1, -3), cf(2022, 1, 1, 2), cf(2023, 1, 1, -1)];
      expect(() => xirr(flows), throwsA(isA<NonConvergenceException>()));
    });

    test('exception details and toString', () {
      try {
        xirr([cf(2021, 1, 1, -100), cf(2022, 1, 1, 1100)],
            options: const XirrOptions(maxRate: 5));
        fail('should throw');
      } on NonConvergenceException catch (e) {
        expect(e.iterations, greaterThanOrEqualTo(0));
        expect(e.toString(), startsWith('NonConvergenceException: '));
        expect(e.message, isNotEmpty);
      }
      expect(
        const InsufficientCashFlowsException(0).toString(),
        contains('InsufficientCashFlowsException'),
      );
      expect(InvalidCashFlowException(3, double.nan).toString(),
          contains('index 3'));
    });

    test('catching the base type', () {
      XirrException? caught;
      try {
        xirr([]);
      } on XirrException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      // sealed: exhaustive switch compiles
      final label = switch (caught!) {
        InsufficientCashFlowsException() => 'few',
        NoSignChangeException() => 'sign',
        NonConvergenceException() => 'conv',
        InvalidCashFlowException() => 'invalid',
      };
      expect(label, 'few');
    });
  });

  group('auto fallback', () {
    test('-99.999999 %: Newton struggles, Brent finishes', () {
      final flows = [cf(2021, 1, 1, -100), cf(2022, 1, 1, 1e-6)];
      final r = xirrDetailed(flows);
      expect(r.converged, isTrue);
      expect(r.method, SolverMethod.brent);
      expect(r.rate, closeTo(1e-8 - 1, 1e-12));
      expect(xirr(flows), r.rate);
    });

    test('100 year horizon ending near zero', () {
      final flows = [cf(1950, 1, 1, -100), cf(2050, 1, 1, 1e-20)];
      final r = xirrDetailed(flows);
      expect(r.converged, isTrue);
      expect(r.method, SolverMethod.brent);
      expect(r.iterations, greaterThan(50));
    });

    test('a root beyond maxRate is reported, not invented', () {
      final flows = [cf(2021, 1, 1, -1), cf(2021, 1, 3, 1e6)];
      final r = xirrDetailed(flows);
      expect(r.converged, isFalse);
      expect(() => xirr(flows), throwsA(isA<NonConvergenceException>()));
    });
  });

  group('xirrDetailed', () {
    test('reports diagnostics', () {
      final r = xirrDetailed(microsoftExample());
      expect(r.converged, isTrue);
      expect(r.rate, closeTo(0.373362535, 5e-9));
      expect(r.method, SolverMethod.newton);
      expect(r.iterations, inInclusiveRange(1, 20));
      expect(r.residual.abs(), lessThan(1e-6));
      expect(r.cashFlowCount, 5);
      expect(r.toString(), contains('converged: true'));
    });

    test('reports the method that actually ran', () {
      expect(
        xirrDetailed(microsoftExample(),
                options: const XirrOptions(method: SolverMethod.brent))
            .method,
        SolverMethod.brent,
      );
      expect(
        xirrDetailed(microsoftExample(),
                options: const XirrOptions(method: SolverMethod.bisection))
            .method,
        SolverMethod.bisection,
      );
    });

    test('does not throw on non-convergence, flags it', () {
      final r = xirrDetailed(
        [cf(2021, 1, 1, -100), cf(2022, 1, 1, 1100)],
        options: const XirrOptions(maxRate: 5),
      );
      expect(r.converged, isFalse);
      expect(r.rate.isNaN || r.rate.isFinite, isTrue);
    });

    test('limited iterations are reported as not converged', () {
      final r = xirrDetailed(
        microsoftExample(),
        options:
            const XirrOptions(method: SolverMethod.newton, maxIterations: 1),
      );
      expect(r.converged, isFalse);
      expect(r.iterations, 1);
    });
  });

  group('performance', () {
    test('10,000 daily SIP flows in under 200 ms', () {
      final flows = <CashFlow>[
        for (var i = 0; i < 10000; i++)
          CashFlow(DateTime.utc(1998, 1, 1 + i), -100.0 - (i % 7)),
        CashFlow(DateTime.utc(2025, 6, 1), 2.4e6),
      ];
      xirr(flows); // warm-up
      final sw = Stopwatch()..start();
      final r = xirr(flows);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(200));
      expect(r, greaterThan(0));
      expect(xnpv(r, flows).abs(), lessThan(1e-3));
    });

    test('10,000 flows with Brent and bisection also finish quickly', () {
      final flows = <CashFlow>[
        for (var i = 0; i < 10000; i++)
          CashFlow(DateTime.utc(1998, 1, 1 + i), -100.0),
        CashFlow(DateTime.utc(2025, 6, 1), 2.0e6),
      ];
      for (final m in [SolverMethod.brent, SolverMethod.bisection]) {
        final sw = Stopwatch()..start();
        xirr(flows, options: XirrOptions(method: m));
        expect(sw.elapsedMilliseconds, lessThan(1000), reason: m.name);
      }
    });
  });
}

extension on List<CashFlow> {
  void swap(int i, int j) {
    final t = this[i];
    this[i] = this[j];
    this[j] = t;
  }
}
